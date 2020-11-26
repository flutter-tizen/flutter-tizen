// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/executable.dart';
import 'package:flutter_tools/src/commands/analyze.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../tizen_plugins.dart';

class TizenAnalyzeCommand extends AnalyzeCommand with TizenExtension {
  /// Source: [main] in `executable.dart`
  TizenAnalyzeCommand({bool verboseHelp = false})
      : super(
          verboseHelp: verboseHelp,
          fileSystem: globals.fs,
          platform: globals.platform,
          processManager: globals.processManager,
          logger: globals.logger,
          terminal: globals.terminal,
          artifacts: globals.artifacts,
        );
}
