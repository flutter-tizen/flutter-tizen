// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tools/src/commands/run.dart';

import '../tizen_cache.dart';
import '../tizen_plugins.dart';

class TizenRunCommand extends RunCommand
    with DartPluginRegistry, TizenRequiredArtifacts {
  TizenRunCommand({bool verboseHelp = false}) : super(verboseHelp: verboseHelp);
}
