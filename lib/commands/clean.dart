// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/commands/clean.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:path/path.dart';

import '../tizen_project.dart';

class TizenCleanCommand extends CleanCommand {
  TizenCleanCommand({bool verbose = false}) : super(verbose: verbose);

  /// See: [CleanCommand.runCommand] in `clean.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    final FlutterProject flutterProject = FlutterProject.current();
    _cleanTizenProject(TizenProject.fromFlutter(flutterProject));

    return await super.runCommand();
  }

  void _cleanTizenProject(TizenProject project) {
    if (!project.existsSync()) {
      return;
    }
    _deleteFile(project.ephemeralDirectory);

    if (project.isDotnet) {
      _deleteFile(project.editableDirectory.childDirectory('bin'));
      _deleteFile(project.editableDirectory.childDirectory('obj'));
    } else {
      _deleteFile(project.editableDirectory.childDirectory('Debug'));
      _deleteFile(project.editableDirectory.childDirectory('Release'));
    }
  }

  /// Source: [CleanCommand.deleteFile] in `clean.dart` (simplified)
  void _deleteFile(FileSystemEntity file) {
    if (!file.existsSync()) {
      return;
    }
    final String path = relative(file.path);
    final Status status = globals.logger.startProgress(
      'Deleting $path...',
    );
    try {
      file.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      globals.printError('Failed to remove $path: $error');
    } finally {
      status?.stop();
    }
  }
}
