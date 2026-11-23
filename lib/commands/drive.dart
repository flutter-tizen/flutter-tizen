// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/drive.dart';

import '../tizen_cache.dart';
import '../tizen_plugins.dart';

class TizenDriveCommand extends DriveCommand with DartPluginRegistry, TizenRequiredArtifacts {
  TizenDriveCommand({
    required super.buildSystem,
    required super.buildTargets,
    required super.toolContext,
    super.verboseHelp,
  });
}
