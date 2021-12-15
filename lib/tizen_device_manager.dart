// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
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

import 'tizen_device_discovery.dart';
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
          tizenSdk: tizenSdk,
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
