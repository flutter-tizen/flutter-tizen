// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/commands/run.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/target_devices.dart';

import '../tizen_cache.dart';
import '../tizen_device.dart';
import '../tizen_plugins.dart';

class TizenRunCommand extends RunCommand with DartPluginRegistry, TizenRequiredArtifacts {
  TizenRunCommand({super.verboseHelp});

  @override
  Future<List<Device>?> findAllTargetDevices({
    bool includeDevicesUnsupportedByProject = false,
  }) async {
    final tizenDeviceLogger = TizenDeviceLogger(
      logger: globals.logger,
      deviceManager: globals.deviceManager!,
    );
    return TargetDevices(
      deviceManager: globals.deviceManager!,
      logger: tizenDeviceLogger,
      deviceConnectionInterface: deviceConnectionInterface,
      platform: globals.platform,
    ).findAllTargetDevices(
      deviceDiscoveryTimeout: deviceDiscoveryTimeout,
      includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
    );
  }
}

/// A [Logger] that fixes the device information for Tizen devices.
class TizenDeviceLogger extends DelegatingLogger {
  TizenDeviceLogger({
    required Logger logger,
    required DeviceManager deviceManager,
  })  : _deviceManager = deviceManager,
        super(logger);

  final DeviceManager _deviceManager;

  @override
  Future<void> printStatus(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    bool? newline,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) async {
    for (final Device device in await _deviceManager.getDevices()) {
      if (device is TizenDevice) {
        if (message.contains(device.name) && message.contains('Tizen')) {
          message = message
              .replaceFirst('(${Category.mobile})',
                  '(${device.deviceProfile})${device.deviceProfile == 'tv' ? '    ' : ''}')
              .replaceFirst(
                getNameForTargetPlatform(TargetPlatform.tester),
                'tizen-${device.architecture}${device.architecture == 'arm64' ? '   ' : '     '}',
              );
        }
      }
    }
    super.printStatus(
      message,
      emphasis: emphasis,
      color: color,
      newline: newline,
      indent: indent,
      hangingIndent: hangingIndent,
      wrap: wrap,
    );
  }
}
