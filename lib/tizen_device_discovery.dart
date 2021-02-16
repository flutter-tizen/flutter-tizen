// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_tools/src/android/android_device_discovery.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/context_runner.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/fuchsia/fuchsia_workflow.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/macos/macos_workflow.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'tizen_device.dart';
import 'tizen_doctor.dart';
import 'tizen_sdk.dart';

/// An extended [DeviceManager] for managing Tizen devices.
class TizenDeviceManager extends FlutterDeviceManager {
  /// Source: [runInContext] in `context_runner.dart`
  TizenDeviceManager()
      : super(
          logger: globals.logger,
          processManager: globals.processManager,
          platform: globals.platform,
          androidSdk: globals.androidSdk,
          iosSimulatorUtils: globals.iosSimulatorUtils,
          featureFlags: featureFlags,
          fileSystem: globals.fs,
          iosWorkflow: globals.iosWorkflow,
          artifacts: globals.artifacts,
          flutterVersion: globals.flutterVersion,
          androidWorkflow: androidWorkflow,
          config: globals.config,
          fuchsiaWorkflow: fuchsiaWorkflow,
          xcDevice: globals.xcdevice,
          macOSWorkflow: MacOSWorkflow(
            platform: globals.platform,
            featureFlags: featureFlags,
          ),
        );

  @override
  List<DeviceDiscovery> get deviceDiscoverers => <DeviceDiscovery>[
        ...super.deviceDiscoverers,
        TizenDeviceDiscovery(
          tizenWorkflow: tizenWorkflow,
          logger: globals.logger,
          processManager: globals.processManager,
        ),
      ];
}

/// Device discovery for Tizen devices.
///
/// Source: [AndroidDevices] in `android_device_discovery.dart`
class TizenDeviceDiscovery extends PollingDeviceDiscovery {
  TizenDeviceDiscovery({
    @required TizenWorkflow tizenWorkflow,
    @required ProcessManager processManager,
    @required Logger logger,
  })  : _tizenWorkflow = tizenWorkflow,
        _logger = logger,
        _processManager = processManager,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        super('Tizen devices');

  final TizenWorkflow _tizenWorkflow;
  final Logger _logger;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;

  @override
  bool get supportsPlatform => _tizenWorkflow.appliesToHostPlatform;

  @override
  bool get canListAnything => _tizenWorkflow.canListDevices;

  @override
  Future<List<Device>> pollingGetDevices({Duration timeout}) async {
    if (tizenSdk == null) {
      return <TizenDevice>[];
    }

    String stdout;
    try {
      final RunResult result = await _processUtils
          .run(<String>[tizenSdk.sdb.path, 'devices'], throwOnError: true);
      stdout = result.stdout.trim();
    } on ProcessException catch (ex) {
      throwToolExit('sdb failed to list connected devices:\n$ex');
    }

    final List<TizenDevice> devices = <TizenDevice>[];
    for (final String line in LineSplitter.split(stdout)) {
      if (line.startsWith('* ') ||
          line.startsWith('  ') ||
          line.startsWith('List of devices')) {
        continue;
      }

      final List<String> splitLine = line.split(RegExp(r'\s{2,}|\t'));
      if (splitLine.length != 3) {
        continue;
      }

      final String deviceId = splitLine[0];
      final String deviceStatus = splitLine[1];
      final String deviceModel = splitLine[2];

      // TODO(swift-kim): Warn about unknown (offline) devices.
      if (deviceStatus != 'device') {
        continue;
      }

      devices.add(TizenDevice(
        deviceId,
        modelId: deviceModel,
        logger: _logger ?? globals.logger,
        tizenSdk: tizenSdk,
        processManager: _processManager ?? globals.processManager,
      ));
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
    final String stderr = result.stderr.trim();

    final List<String> messages = <String>[];
    for (final String line in LineSplitter.split(stderr)) {
      if (line.startsWith('* ') || line.startsWith('  ')) {
        messages.add(line.substring(2).replaceAll(' *', ''));
      }
    }
    return messages;
  }
}
