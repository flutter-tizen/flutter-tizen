// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/install.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_device.dart';
import '../tizen_tpk.dart';

class TizenInstallCommand extends InstallCommand {
  TizenInstallCommand();

  final TpkStore tizenAppPackages = TpkStore();

  @override
  Future<FlutterCommandResult> runCommand() {
    // Unlike [ApplicationPackageFactory], [ApplicationPackageStore] cannot be
    // overriden by the context runner. Thus, we directly assign it just before
    // executing the command.
    if (device is TizenDevice) {
      applicationPackages = tizenAppPackages;
    }
    return super.runCommand();
  }
}
