// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/device_port_forwarder.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/vmservice.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

/// Default factory that creates a real socket connection.
Future<Socket> kSocketFactory(String host, int port) => Socket.connect(host, port);

/// Override this in tests with an implementation that returns mock responses.
typedef SocketFactory = Future<Socket> Function(String host, int port);

class ForwardingLogReader extends DeviceLogReader {
  ForwardingLogReader._(
    this.name,
    this.hostPort, {
    required DevicePortForwarder portForwarder,
    required SocketFactory socketFactory,
  })  : _portForwarder = portForwarder,
        _socketFactory = socketFactory;

  static Future<ForwardingLogReader> createLogReader(
    Device device, {
    SocketFactory socketFactory = kSocketFactory,
  }) async {
    return ForwardingLogReader._(
      device.name,
      await globals.os.findFreePort(),
      portForwarder: device.portForwarder!,
      socketFactory: socketFactory,
    );
  }

  @override
  final String name;

  final int hostPort;

  final DevicePortForwarder _portForwarder;
  final SocketFactory _socketFactory;
  Socket? _socket;

  final _linesController = StreamController<String>.broadcast();

  static const String _inspectorPubRootDirectoriesExtensionName =
      'ext.flutter.inspector.addPubRootDirectories';

  // For Inspector pub root registration on hot restart
  StreamSubscription<vm_service.Event>? _isolateEventSubscription;

  @override
  Stream<String> get logLines => _linesController.stream;

  final _logFormat = RegExp(r'^(\[[IWEF]\]).*');

  String _colorizePrefix(String message) {
    if (!globals.terminal.supportsColor) {
      return message;
    }
    final Match? match = _logFormat.firstMatch(message);
    if (match == null) {
      return message;
    }
    final String prefix = match.group(1)!;
    final TerminalColor? color = switch (prefix) {
      '[I]' => TerminalColor.cyan,
      '[W]' => TerminalColor.yellow,
      '[E]' => TerminalColor.red,
      '[F]' => TerminalColor.magenta,
      _ => null,
    };
    if (color == null) {
      return message;
    }
    return message.replaceFirst(prefix, globals.terminal.color(prefix, color));
  }

  final _filteredTexts = <RegExp>[
    // Issue: https://github.com/flutter-tizen/engine/issues/91
    RegExp('xkbcommon: ERROR:'),
    RegExp("couldn't find a Compose file for locale"),
    // Issue: https://github.com/flutter-tizen/engine/issues/348
    RegExp(r'\[WARN\].+wl_egl_window.+already rotated'),
    // Thread added[0xfabcde, pid:12345 tid: 12345] to display:0xfbcdef, threads_cnt=1
    // Thread removed[0xfabcde pid:12345 tid: 12345] from display:0xfbcdef, threads_cnt=0
    RegExp('Thread added.+ to display:'),
    RegExp('Thread removed.+ from display:'),
  ];

  Future<Socket?> _connectAndListen() async {
    globals.printTrace('Connecting to localhost:$hostPort...');
    Socket? socket = await _socketFactory('localhost', hostPort);

    const decoder = Utf8Decoder(allowMalformed: true);
    final completer = Completer<void>();

    socket.listen(
      (Uint8List data) {
        String response = decoder.convert(data).trim();
        if (!completer.isCompleted) {
          if (response.startsWith('ACCEPTED')) {
            response = response.substring(8);
          } else {
            globals.printError(
              'Invalid message received from the device logger: $response',
            );
            socket?.destroy();
            socket = null;
          }
          completer.complete();
        }
        for (final String line in LineSplitter.split(response)) {
          if (line.isEmpty || _filteredTexts.any((RegExp re) => re.hasMatch(line))) {
            continue;
          }
          _linesController.add(_colorizePrefix(line));
        }
      },
      onError: (Object error) {
        globals.printError(
          'An error occurred while reading from socket: $error',
        );
        if (!completer.isCompleted) {
          socket?.destroy();
          socket = null;
          completer.complete();
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          socket?.destroy();
          socket = null;
          completer.complete();
        }
      },
      cancelOnError: true,
    );

    await completer.future;
    return socket;
  }

  /// Starts receiving messages from the device logger.
  Future<void> start() async {
    if (_socket != null) {
      globals.printTrace('Already connected to the device logger.');
      return;
    }

    // The host port is also used as a device port. This could result in a
    // binding error if the port is already in use by another process on the
    // device.
    // The forwarded port will be automatically unforwarded when portForwarder
    // is disposed.
    await _portForwarder.forward(hostPort, hostPort: hostPort);

    var attempts = 0;
    try {
      while (true) {
        attempts += 1;
        _socket = await _connectAndListen();
        if (_socket != null) {
          globals.printTrace(
            'The logging service started at ${_socket!.remoteAddress.address}:${_socket!.remotePort}.',
          );
          break;
        }
        if (attempts == 10) {
          globals.printError(
            'Connecting to the device logger is taking longer than expected...',
          );
        } else if (attempts == 20) {
          globals.printError(
            'Still attempting to connect to the device logger...\n'
            'If you do not see the application running on the device, it might have crashed. The device log (dlog) might have more details.\n'
            'Please open an issue in https://github.com/flutter-tizen/flutter-tizen/issues if the problem persists.',
          );
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } on Exception catch (error) {
      throwToolExit('Connection failed: $error');
    }
  }

  @override
  void dispose() {
    _socket?.destroy();
    _linesController.close();
    _isolateEventSubscription?.cancel();
  }

  @override
  Future<void> provideVmService(FlutterVmService connectedVmService) async {
    // Register the correct project root directory with the Widget Inspector.
    // This is necessary because flutter-tizen uses a generated entrypoint at
    // tizen/flutter/generated_main.dart, which causes DevTools to incorrectly
    // set the pub root to tizen/flutter/ instead of the actual project root.
    // Without this fix, DevTools Inspector shows an empty widget tree.
    await _setupInspectorPubRootRegistration(connectedVmService);
  }

  /// Sets up registration of the project root with the Inspector on initial
  /// load and after each hot restart when the isolate re-registers extensions.
  Future<void> _setupInspectorPubRootRegistration(
    FlutterVmService vmService,
  ) async {
    // Initial registration
    try {
      final String? maybeIsolateId =
          (await vmService.findExtensionIsolate(_inspectorPubRootDirectoriesExtensionName)).id;

      if (maybeIsolateId case final isolateId?) {
        await _registerProjectRoot(vmService, isolateId);
      } else {
        globals.printTrace('Inspector extension not found');
      }
    } on VmServiceDisappearedException {
      globals.printTrace('VM Service disappeared before Inspector registration');
      return;
    } on Exception catch (e) {
      globals.printTrace('Failed initial Inspector pub root registration: $e');
    }

    // Re-register after hot restart
    _isolateEventSubscription = vmService.service.onIsolateEvent.listen((event) async {
      if (event
          case vm_service.Event(
            kind: vm_service.EventKind.kServiceExtensionAdded,
            extensionRPC: _inspectorPubRootDirectoriesExtensionName,
            isolate: vm_service.IsolateRef(id: final isolateId?)
          )) {
        globals.printTrace('Inspector extension re-registered after restart: Isolate $isolateId');

        await _registerProjectRoot(vmService, isolateId);
      }
    });
  }

  /// Registers the project root directory with the Inspector.
  Future<void> _registerProjectRoot(
    FlutterVmService vmService,
    String isolateId,
  ) async {
    final String projectRoot = FlutterProject.current().directory.path;

    globals.printTrace('Registering Inspector pub root: $projectRoot');

    try {
      await vmService.invokeFlutterExtensionRpcRaw(
        _inspectorPubRootDirectoriesExtensionName,
        isolateId: isolateId,
        args: <String, Object?>{'arg0': projectRoot},
      );

      globals.printTrace('Inspector pub root registered successfully');
    } on Exception catch (e) {
      globals.printTrace('Failed to register Inspector pub root: $e');
    }
  }
}
