// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tools/src/commands/drive.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../tizen_cache.dart';
import '../tizen_plugins.dart';

class TizenDriveCommand extends DriveCommand
    with TizenExtension, TizenRequiredArtifacts {
  TizenDriveCommand({bool verboseHelp = false})
      : super(
          verboseHelp: verboseHelp,
          fileSystem: globals.fs,
          logger: globals.logger,
          platform: globals.platform,
        );
}
