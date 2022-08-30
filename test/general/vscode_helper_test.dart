// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/vscode_helper.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/project.dart';

import '../src/common.dart';

const String _kLaunchJson = r'''
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "flutter-tizen: Attach",
            "request": "attach",
            "type": "dart",
            "deviceId": "flutter-tester",
            "cwd": "${workspaceFolder}",
            "vmServiceUri": "http://127.0.0.1:12345"
        }
    ]
}''';

const String _kEmptyLaunchJson = r'''
{
    // This comment will be deleted.
    "version": "0.2.0",
    "configurations": []
}''';

void main() {
  FileSystem fileSystem;
  FlutterProject project;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    project = FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);
  });

  testWithoutContext('Can create launch.json file', () async {
    final File launchJsonFile =
        project.directory.childDirectory('.vscode').childFile('launch.json');
    expect(launchJsonFile, isNot(exists));

    updateLaunchJsonFile(project, Uri.parse('http://127.0.0.1:12345'));

    expect(launchJsonFile, exists);
    expect(launchJsonFile.readAsStringSync(), equals(_kLaunchJson));
  });

  testWithoutContext('Can update launch.json file', () async {
    final File launchJsonFile =
        project.directory.childDirectory('.vscode').childFile('launch.json');
    launchJsonFile.createSync(recursive: true);
    launchJsonFile.writeAsStringSync(_kEmptyLaunchJson);

    updateLaunchJsonFile(project, Uri.parse('http://127.0.0.1:12345'));

    expect(launchJsonFile, exists);
    expect(launchJsonFile.readAsStringSync(), equals(_kLaunchJson));
  });
}
