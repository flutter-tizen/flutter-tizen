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

/// Default factory that creates a real socket connection.
Future<Socket> kSocketFactory(String host, int port) =>
    Socket.connect(host, port);

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

  final StreamController<String> _linesController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get logLines => _linesController.stream;

  final RegExp _logFormat = RegExp(r'^(\[[IWEF]\]).*');

  String _colorizePrefix(String message) {
    final Match? match = _logFormat.firstMatch(message);
    if (match == null) {
      return message;
    }
    final String prefix = match.group(1)!;
    TerminalColor color;
    if (prefix == '[I]') {
      color = TerminalColor.cyan;
    } else if (prefix == '[W]') {
      color = TerminalColor.yellow;
    } else if (prefix == '[E]') {
      color = TerminalColor.red;
    } else if (prefix == '[F]') {
      color = TerminalColor.magenta;
    } else {
      return message;
    }
    return message.replaceFirst(prefix, globals.terminal.color(prefix, color));
  }

  final List<RegExp> _filteredTexts = <RegExp>[
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

    const Utf8Decoder decoder = Utf8Decoder();
    final Completer<void> completer = Completer<void>();

    socket.listen(
      (Uint8List data) {
        String response = decoder.convert(data).trim();
        if (!completer.isCompleted) {
          if (response.startsWith('ACCEPTED')) {
            response = response.substring(8);
          } else {
            globals.printError(
                'Invalid message received from the device logger: $response');
            socket?.destroy();
            socket = null;
          }
          completer.complete();
        }
        for (final String line in LineSplitter.split(response)) {
          if (line.isEmpty ||
              _filteredTexts.any((RegExp re) => re.hasMatch(line))) {
            continue;
          }
          _linesController.add(_colorizePrefix(line));
        }
      },
      onError: (Object error) {
        globals
            .printError('An error occurred while reading from socket: $error');
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

    int attempts = 0;
    try {
      while (true) {
        attempts += 1;
        _socket = await _connectAndListen();
        if (_socket != null) {
          globals.printTrace(
              'The logging service started at ${_socket!.remoteAddress.address}:${_socket!.remotePort}.');
          break;
        }
        if (attempts == 10) {
          globals.printError(
              'Connecting to the device logger is taking longer than expected...');
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
  }
}
