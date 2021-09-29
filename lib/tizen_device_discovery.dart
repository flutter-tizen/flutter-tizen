// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_device_discovery.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/context_runner.dart';
import 'package:flutter_tools/src/custom_devices/custom_devices_config.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_device_manager.dart';
import 'package:flutter_tools/src/fuchsia/fuchsia_workflow.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/macos/macos_workflow.dart';
import 'package:flutter_tools/src/windows/uwptool.dart';
import 'package:flutter_tools/src/windows/windows_workflow.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'tizen_device.dart';
import 'tizen_doctor.dart';
import 'tizen_sdk.dart';

/// An extended [FlutterDeviceManager] for managing Tizen devices.
class TizenDeviceManager extends FlutterDeviceManager {
  /// See: [runInContext] in `context_runner.dart`
  TizenDeviceManager({
    @required Logger logger,
    @required FileSystem fileSystem,
    @required Platform platform,
    @required ProcessManager processManager,
  })  : _tizenDeviceDiscovery = TizenDeviceDiscovery(
          tizenWorkflow: tizenWorkflow,
          logger: logger,
          fileSystem: fileSystem,
          processManager: processManager,
        ),
        super(
          logger: logger,
          processManager: processManager,
          platform: platform,
          androidSdk: globals.androidSdk,
          iosSimulatorUtils: globals.iosSimulatorUtils,
          featureFlags: featureFlags,
          fileSystem: fileSystem,
          iosWorkflow: globals.iosWorkflow,
          artifacts: globals.artifacts,
          flutterVersion: globals.flutterVersion,
          androidWorkflow: androidWorkflow,
          fuchsiaWorkflow: fuchsiaWorkflow,
          xcDevice: globals.xcdevice,
          userMessages: globals.userMessages,
          windowsWorkflow: windowsWorkflow,
          macOSWorkflow: context.get<MacOSWorkflow>(),
          operatingSystemUtils: globals.os,
          terminal: globals.terminal,
          customDevicesConfig: CustomDevicesConfig(
            fileSystem: fileSystem,
            logger: logger,
            platform: platform,
          ),
          uwptool: UwpTool(
            artifacts: globals.artifacts,
            logger: globals.logger,
            processManager: globals.processManager,
          ),
        );

  final TizenDeviceDiscovery _tizenDeviceDiscovery;

  @override
  List<DeviceDiscovery> get deviceDiscoverers => <DeviceDiscovery>[
        ...super.deviceDiscoverers,
        _tizenDeviceDiscovery,
      ];
}

/// Device discovery for Tizen devices.
///
/// Source: [AndroidDevices] in `android_device_discovery.dart`
class TizenDeviceDiscovery extends PollingDeviceDiscovery {
  TizenDeviceDiscovery({
    @required TizenWorkflow tizenWorkflow,
    @required Logger logger,
    @required FileSystem fileSystem,
    @required ProcessManager processManager,
  })  : _tizenWorkflow = tizenWorkflow,
        _logger = logger,
        _fileSystem = fileSystem,
        _processManager = processManager,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        super('Tizen devices');

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
  Future<List<Device>> pollingGetDevices({Duration timeout}) async {
    if (tizenSdk == null || !tizenSdk.sdb.existsSync()) {
      return <TizenDevice>[];
    }

    String stdout;
    try {
      final RunResult result = await _processUtils
          .run(<String>[tizenSdk.sdb.path, 'devices'], throwOnError: true);
      stdout = result.stdout.trim();
    } on ProcessException catch (ex) {
      throwToolExit('sdb failed to list attached devices:\n$ex');
    }

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
        tizenSdk: tizenSdk,
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
    if (tizenSdk == null) {
      return <String>[];
    }

    final RunResult result =
        await _processUtils.run(<String>[tizenSdk.sdb.path, 'devices']);
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
          'Unexpected failure parsing device information from sdb output:\n$line',
        );
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
