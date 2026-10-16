// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/clean.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_project.dart';

class TizenCleanCommand extends CleanCommand {
  TizenCleanCommand({super.verbose});

  @override
  Future<FlutterCommandResult> runCommand() async {
    final FlutterProject flutterProject = FlutterProject.current();
    TizenProject.fromFlutter(flutterProject).clean();
    if (boolArg('include-example') && flutterProject.hasExampleApp) {
      TizenProject.fromFlutter(flutterProject.example).clean();
    }
    return super.runCommand();
  }
}
