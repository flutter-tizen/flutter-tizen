// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_device_discovery.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:process/process.dart';

import 'tizen_device.dart';
import 'tizen_doctor.dart';
import 'tizen_sdk.dart';

/// Device discovery for Tizen devices.
///
/// Source: [AndroidDevices] in `android_device_discovery.dart`
class TizenDeviceDiscovery extends PollingDeviceDiscovery {
  TizenDeviceDiscovery({
    required TizenSdk? tizenSdk,
    required TizenWorkflow tizenWorkflow,
    required Logger logger,
    required FileSystem fileSystem,
    required ProcessManager processManager,
  })  : _tizenSdk = tizenSdk,
        _tizenWorkflow = tizenWorkflow,
        _logger = logger,
        _fileSystem = fileSystem,
        _processManager = processManager,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        super('Tizen devices');

  final TizenSdk? _tizenSdk;
  final TizenWorkflow _tizenWorkflow;
  final Logger _logger;
  final FileSystem _fileSystem;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;

  @override
  bool get supportsPlatform => _tizenWorkflow.appliesToHostPlatform;

  @override
  bool get canListAnything => _tizenWorkflow.canListDevices;

  final RegExp _splitPattern = RegExp(r'\s{2,}|\t');

  @override
  Future<List<Device>> pollingGetDevices({Duration? timeout}) async {
    if (_tizenSdk == null || !_tizenSdk!.sdb.existsSync()) {
      return <TizenDevice>[];
    }

    final RunResult result =
        await _processUtils.run(<String>[_tizenSdk!.sdb.path, 'devices']);
    if (result.exitCode != 0) {
      throwToolExit('sdb failed to list attached devices:\n$result');
    }
    final String stdout = result.stdout.trim();

    final List<TizenDevice> devices = <TizenDevice>[];
    for (final String line in LineSplitter.split(stdout)) {
      if (line.startsWith('List of devices')) {
        continue;
      }

      final List<String> splitLine = line.split(_splitPattern);
      if (splitLine.length != 3) {
        continue;
      }

      final String deviceId = splitLine[0];
      final String deviceState = splitLine[1];
      final String deviceModel = splitLine[2];

      if (deviceState != 'device') {
        continue;
      }

      final TizenDevice device = TizenDevice(
        deviceId,
        modelId: deviceModel,
        logger: _logger,
        processManager: _processManager,
        tizenSdk: _tizenSdk!,
        fileSystem: _fileSystem,
      );

      // Occasionally sdb detects an Android device as a Tizen device.
      // Issue: https://github.com/flutter-tizen/flutter-tizen/issues/30
      try {
        // This call fails for non-Tizen devices.
        device.getCapability('cpu_arch');
      } on ProcessException {
        continue;
      }

      devices.add(device);
    }
    return devices;
  }

  @override
  Future<List<String>> getDiagnostics() async {
    if (_tizenSdk == null) {
      return <String>[];
    }

    final RunResult result =
        await _processUtils.run(<String>[_tizenSdk!.sdb.path, 'devices']);
    if (result.exitCode != 0) {
      return <String>[];
    }
    final String output = result.toString();
    if (!output.contains('List of devices')) {
      return <String>[output];
    }

    final List<String> messages = <String>[];
    for (final String line in LineSplitter.split(output)) {
      if (line.startsWith('List of devices')) {
        continue;
      }

      if (line.startsWith('* ') || line.startsWith('  ')) {
        messages.add(line.substring(2).replaceAll(' *', ''));
        continue;
      }

      final List<String> splitLine = line.split(_splitPattern);
      if (splitLine.length != 3) {
        messages.add(
            'Unexpected failure parsing device information from sdb output:\n$line');
        continue;
      }

      final String deviceId = splitLine[0];
      final String deviceState = splitLine[1];

      if (deviceState == 'unauthorized') {
        messages.add(
          'Device $deviceId is not authorized.\n'
          'You might need to check your device for an authorization dialog.',
        );
      } else if (deviceState == 'offline') {
        messages.add('Device $deviceId is offline.');
      } else if (deviceState == 'unknown') {
        messages.add('Device $deviceId is not ready.');
      }
    }
    return messages;
  }

  @override
  List<String> get wellKnownIds => const <String>[];
}
