// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:flutter_tizen/commands/clean.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/test_flutter_command_runner.dart';

void main() {
  FileSystem fileSystem;
  Directory tizenDir;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.file('pubspec.yaml').createSync(recursive: true);
    tizenDir = fileSystem.directory('tizen');
    tizenDir.childFile('tizen-manifest.xml').createSync(recursive: true);
  });

  testUsingContext('Can clean C# project', () async {
    final TizenCleanCommand command = TizenCleanCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);

    tizenDir.childFile('Runner.csproj').createSync(recursive: true);

    final Directory flutterDir = tizenDir.childDirectory('flutter')
      ..createSync(recursive: true);
    final Directory binDir = tizenDir.childDirectory('bin')
      ..createSync(recursive: true);
    final Directory objDir = tizenDir.childDirectory('obj')
      ..createSync(recursive: true);
    final File userFile = tizenDir.childFile('Runner.csproj.user')
      ..createSync(recursive: true);

    await runner.run(<String>['clean']);

    expect(flutterDir.existsSync(), isFalse);
    expect(binDir.existsSync(), isFalse);
    expect(objDir.existsSync(), isFalse);
    expect(userFile.existsSync(), isFalse);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('Can clean C++ project', () async {
    final TizenCleanCommand command = TizenCleanCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);

    tizenDir.childFile('project_def.prop').createSync(recursive: true);

    final Directory flutterDir = tizenDir.childDirectory('flutter')
      ..createSync(recursive: true);
    final Directory debugDir = tizenDir.childDirectory('Debug')
      ..createSync(recursive: true);
    final Directory releaseDir = tizenDir.childDirectory('Release')
      ..createSync(recursive: true);

    await runner.run(<String>['clean']);

    expect(flutterDir.existsSync(), isFalse);
    expect(debugDir.existsSync(), isFalse);
    expect(releaseDir.existsSync(), isFalse);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  });
}
