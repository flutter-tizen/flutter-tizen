// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/commands/drive.dart';
import 'package:meta/meta.dart';

import '../tizen_cache.dart';
import '../tizen_plugins.dart';

class TizenDriveCommand extends DriveCommand
    with DartPluginRegistry, TizenRequiredArtifacts {
  TizenDriveCommand({
    bool verboseHelp = false,
    @required FileSystem fileSystem,
    @required Logger logger,
    @required Platform platform,
  }) : super(
          verboseHelp: verboseHelp,
          fileSystem: fileSystem,
          logger: logger,
          platform: platform,
        );
}
