// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/commands/clean.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/macos/xcode.dart';

import '../src/context.dart';
import '../src/test_flutter_command_runner.dart';

void main() {
  late FileSystem fileSystem;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.file('pubspec.yaml').createSync();
    fileSystem.file('example/pubspec.yaml').createSync(recursive: true);
    fileSystem.file('example/tizen/Runner.csproj').createSync(recursive: true);
    fileSystem.directory('example/tizen/flutter').createSync();
    fileSystem.directory('example/tizen/bin').createSync();
    fileSystem.directory('example/tizen/obj').createSync();
  });

  testUsingContext('Cleans the example Tizen project with --include-example', () async {
    final CommandRunner<void> runner = createTestCommandRunner(TizenCleanCommand());
    await runner.run(<String>['clean', '--include-example']);

    expect(fileSystem.directory('example/tizen/flutter'), isNot(exists));
    expect(fileSystem.directory('example/tizen/bin'), isNot(exists));
    expect(fileSystem.directory('example/tizen/obj'), isNot(exists));
    expect(fileSystem.file('example/tizen/Runner.csproj'), exists);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    Xcode: () => null,
  });

  testUsingContext('Does not clean the example Tizen project by default', () async {
    final CommandRunner<void> runner = createTestCommandRunner(TizenCleanCommand());
    await runner.run(<String>['clean']);

    expect(fileSystem.directory('example/tizen/flutter'), exists);
    expect(fileSystem.directory('example/tizen/bin'), exists);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    Xcode: () => null,
  });

  testUsingContext('Does not fail with --include-example if there is no example', () async {
    fileSystem.directory('example').deleteSync(recursive: true);

    final CommandRunner<void> runner = createTestCommandRunner(TizenCleanCommand());
    await runner.run(<String>['clean', '--include-example']);

    expect(testLogger.statusText, contains('No example app found'));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    Xcode: () => null,
  });
}
