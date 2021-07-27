// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/commands/analyze.dart';
import 'package:meta/meta.dart';
import 'package:process/src/interface/process_manager.dart';

import '../tizen_plugins.dart';

class TizenAnalyzeCommand extends AnalyzeCommand with TizenExtension {
  TizenAnalyzeCommand({
    bool verboseHelp = false,
    Directory workingDirectory,
    @required FileSystem fileSystem,
    @required Platform platform,
    @required Terminal terminal,
    @required Logger logger,
    @required ProcessManager processManager,
    @required Artifacts artifacts,
  }) : super(
          verboseHelp: verboseHelp,
          workingDirectory: workingDirectory,
          fileSystem: fileSystem,
          platform: platform,
          terminal: terminal,
          logger: logger,
          processManager: processManager,
          artifacts: artifacts,
        );
}
