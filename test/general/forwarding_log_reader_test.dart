// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_tizen/forwarding_log_reader.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/device_port_forwarder.dart';
import 'package:test/fake.dart';

import '../src/common.dart';
import '../src/context.dart';

void main() {
  late BufferLogger logger;
  late Device device;

  setUp(() {
    logger = BufferLogger.test();
    device = _FakeDevice();
  });

  testUsingContext('Can receive message from the device logger', () async {
    final ForwardingLogReader logReader = await ForwardingLogReader.createLogReader(
      device,
      socketFactory: (String host, int port) async => _FakeWorkingSocket('Message'),
    );
    await logReader.start();

    expect(logReader.hostPort, isNotNull);
    expect(await logReader.logLines.first, equals('Message'));
  });

  testUsingContext('The device logger is unresponsive', () async {
    final ForwardingLogReader logReader = await ForwardingLogReader.createLogReader(
      device,
      socketFactory: (String host, int port) async => _FakeNoResponseSocket(),
    );
    FakeAsync().run((FakeAsync time) {
      unawaited(logReader.start());

      time.elapse(const Duration(seconds: 5));
      expect(logger.errorText, isEmpty);

      time.elapse(const Duration(seconds: 20));
      expect(
        logger.errorText,
        contains('Connecting to the device logger is taking longer than expected'),
      );

      time.elapse(const Duration(seconds: 20));
      expect(
        logger.errorText,
        contains('Still attempting to connect to the device logger'),
      );
    });
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });

  testUsingContext('Connection error', () async {
    final ForwardingLogReader logReader = await ForwardingLogReader.createLogReader(
      device,
      socketFactory: (String host, int port) => throw Exception('Socket error'),
    );
    await expectLater(
      () => logReader.start(),
      throwsToolExit(message: 'Connection failed:'),
    );
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });
}

// ignore: avoid_implementing_value_types
class _FakeDevice extends Fake implements Device {
  _FakeDevice();

  @override
  final String name = 'Device';

  @override
  final DevicePortForwarder portForwarder = const NoOpDevicePortForwarder();
}

class _FakeSocket extends Fake implements Socket {
  _FakeSocket();

  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;

  @override
  int get remotePort => 12345;

  @override
  void destroy() {}
}

class _FakeNoResponseSocket extends _FakeSocket {
  _FakeNoResponseSocket();

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    const Stream<Uint8List> stream = Stream<Uint8List>.empty();
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeWorkingSocket extends _FakeSocket {
  _FakeWorkingSocket(this._message);

  final String _message;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    const Utf8Encoder encoder = Utf8Encoder();
    final Stream<Uint8List> stream = Stream<Uint8List>.fromIterable(<Uint8List>[
      encoder.convert('ACCEPTED'),
      encoder.convert(_message),
    ]);
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
