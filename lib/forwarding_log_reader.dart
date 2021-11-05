// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/device_port_forwarder.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import 'tizen_device.dart';

class ForwardingLogReader extends DeviceLogReader {
  ForwardingLogReader._(this.name, this.hostPort, this.portForwarder) {
    _linesController = StreamController<String>.broadcast();
  }

  static Future<ForwardingLogReader> createLogReader(TizenDevice device) async {
    return ForwardingLogReader._(
      device.name,
      await globals.os.findFreePort(ipv6: false),
      device.portForwarder,
    );
  }

  @override
  final String name;

  final int hostPort;

  final DevicePortForwarder portForwarder;

  StreamController<String> _linesController;
  Socket _socket;

  @override
  Stream<String> get logLines => _linesController.stream;

  Future<void> start() async {
    Future<Socket> connect(int hostPort) async {
      Socket socket = await Socket.connect('localhost', hostPort);
      final Completer<void> completer = Completer<void>();
      const Utf8Decoder decoder = Utf8Decoder();
      bool isHandshakeDone = false;
      socket.listen(
        (Uint8List data) {
          String response = decoder.convert(data).trim();
          globals.printError('[[ $response ]]');
          if (!isHandshakeDone) {
            if (!response.startsWith('ACCEPTED')) {
              globals.printError(
                  'Something went wrong! $response (${response.length})');
              socket.destroy();
              socket = null;
            } else {
              isHandshakeDone = true;
              response = response.substring(8);
            }
            completer.complete();
          }
          response.split('\n').forEach((String line) {
            if (line.isNotEmpty) {
              _linesController.add(line);
            }
          });
        },
        onError: (dynamic error) {
          globals.printTrace(error.toString());
          socket.destroy();
          socket = null;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onDone: () async {
          socket?.destroy();
          socket = null;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );
      await completer.future;
      return socket;
    }

    int devicePort = hostPort;
    await portForwarder.forward(devicePort, hostPort: hostPort);
    _socket = await connect(hostPort);
    if (_socket == null) {
      await Future<void>.delayed(const Duration(seconds: 2));
      globals.printStatus('Try again');
      _socket = await connect(hostPort);
    }
    // if (_socket == null) {
    //   globals.printStatus('Failed to connect!');
    //   await portForwarder.unforward(ForwardedPort(hostPort, devicePort));
    //   devicePort += 1;
    //   await portForwarder.forward(devicePort, hostPort: hostPort);
    //   _socket = await connect(hostPort);
    // }
    if (_socket == null) {
      globals.printError('Failed to connect!');
      await portForwarder.unforward(ForwardedPort(hostPort, devicePort));
      return;
    }

    // TODO: unforward forwared ports

    // TODO: change to printTrace
    globals.printStatus(
        'Connected to ${_socket.remoteAddress.address}:${_socket.remotePort}.');
    // _socket.listen(
    //   (Uint8List data) {
    //     String res = decoder.convert(data);
    //     final String response = String.fromCharCodes(data);
    //     // TODO: What's the maximum length of response?
    //     // TODO: multiline message?
    //     globals.printStatus('RECEIVED: [[ $response ]]');
    //     response.split('\n').map(_linesController.add);
    //   },
    //   onError: (dynamic error) {
    //     globals.printTrace(error.toString());
    //   },
    // );
  }

  @override
  void dispose() {
    _socket?.destroy();
    _linesController.close();
  }
}
