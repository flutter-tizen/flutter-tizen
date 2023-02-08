// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/context_runner.dart';
import 'package:flutter_tools/src/custom_devices/custom_devices_config.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_device_manager.dart';
import 'package:flutter_tools/src/fuchsia/fuchsia_workflow.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/macos/macos_workflow.dart';
import 'package:flutter_tools/src/windows/windows_workflow.dart';

import 'tizen_device_discovery.dart';
import 'tizen_doctor.dart';
import 'tizen_sdk.dart';

/// An extended [FlutterDeviceManager] for managing Tizen devices.
class TizenDeviceManager extends FlutterDeviceManager {
  /// See: [runInContext] in `context_runner.dart`
  TizenDeviceManager()
      : _tizenDeviceDiscovery = TizenDeviceDiscovery(
          tizenSdk: tizenSdk,
          tizenWorkflow: tizenWorkflow!,
          logger: globals.logger,
          fileSystem: globals.fs,
          processManager: globals.processManager,
        ),
        super(
          logger: globals.logger,
          processManager: globals.processManager,
          platform: globals.platform,
          androidSdk: globals.androidSdk,
          iosSimulatorUtils: globals.iosSimulatorUtils!,
          featureFlags: featureFlags,
          fileSystem: globals.fs,
          iosWorkflow: globals.iosWorkflow!,
          artifacts: globals.artifacts!,
          flutterVersion: globals.flutterVersion,
          androidWorkflow: androidWorkflow!,
          fuchsiaWorkflow: fuchsiaWorkflow!,
          xcDevice: globals.xcdevice!,
          userMessages: globals.userMessages,
          windowsWorkflow: windowsWorkflow!,
          macOSWorkflow: context.get<MacOSWorkflow>()!,
          fuchsiaSdk: globals.fuchsiaSdk!,
          operatingSystemUtils: globals.os,
          customDevicesConfig: context.get<CustomDevicesConfig>()!,
        );

  final TizenDeviceDiscovery _tizenDeviceDiscovery;

  @override
  List<DeviceDiscovery> get deviceDiscoverers => <DeviceDiscovery>[
        ...super.deviceDiscoverers,
        _tizenDeviceDiscovery,
      ];
}
