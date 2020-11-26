// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/drive.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_device.dart';
import '../tizen_plugins.dart';
import '../tizen_tpk.dart';

class TizenDriveCommand extends DriveCommand with TizenExtension {
  TizenDriveCommand();

  final TpkStore tizenAppPackages = TpkStore();

  @override
  Future<FlutterCommandResult> runCommand() async {
    if (await findTargetDevice(timeout: deviceDiscoveryTimeout)
        is TizenDevice) {
      applicationPackages = tizenAppPackages;
    }
    return super.runCommand();
  }
}
