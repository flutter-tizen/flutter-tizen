// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/run.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../tizen_cache.dart';
import '../tizen_plugins.dart';
import '../tizen_target_devices.dart';

class TizenRunCommand extends RunCommand with DartPluginRegistry, TizenRequiredArtifacts {
  TizenRunCommand({super.verboseHelp});

  @override
  Future<List<Device>?> findAllTargetDevices({
    bool includeDevicesUnsupportedByProject = false,
  }) async {
    return TizenTargetDevices(
      deviceManager: globals.deviceManager!,
      logger: globals.logger,
      deviceConnectionInterface: deviceConnectionInterface,
    ).findAllTargetDevices(
      deviceDiscoveryTimeout: deviceDiscoveryTimeout,
      includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
    );
  }
}
