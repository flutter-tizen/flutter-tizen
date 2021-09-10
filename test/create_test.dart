// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_tizen/commands/create.dart';
import 'package:flutter_tizen/tizen_pub.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import 'src/common.dart';
import 'src/context.dart';
import 'src/test_flutter_command_runner.dart';

void main() {
  Cache.disableLocking();

  Directory tempDir;
  Directory projectDir;

  setUp(() {
    tempDir = globals.fs.systemTempDirectory
        .createTempSync('flutter_tizen_create_test.');
    projectDir = tempDir.childDirectory('flutter_project');
  });

  testUsingContext(
    'creates multi app properly',
    () async {
      await _createProject(
        projectDir,
        <String>['--app-type', 'multi', '--tizen-language', 'cpp'],
        <String>[
          'tizen/ui/inc/runner.h',
          'tizen/ui/src/runner.cc',
          'tizen/ui/project_def.prop',
          'tizen/ui/tizen-manifest.xml',
          'tizen/service/inc/runner.h',
          'tizen/service/src/runner.cc',
          'tizen/service/project_def.prop',
          'tizen/service/tizen-manifest.xml',
        ],
      );
    },
    overrides: <Type, Generator>{
      Pub: () => TizenPub(
            fileSystem: globals.fs,
            logger: globals.logger,
            processManager: globals.processManager,
            usage: globals.flutterUsage,
            botDetector: globals.botDetector,
            platform: globals.platform,
          ),
    },
  );

  testUsingContext(
    're-running the create command does not modify lib/main.dart',
    () async {
      final TizenCreateCommand command = TizenCreateCommand();
      final CommandRunner<void> runner = createTestCommandRunner(command);

      await runner.run(<String>['create', projectDir.path]);
      final File mainFile =
          projectDir.childDirectory('lib').childFile('main.dart');
      final DateTime lastModifiedTime = mainFile.lastModifiedSync();

      await runner.run(<String>['create', projectDir.path]);
      expect(mainFile.lastModifiedSync().microsecondsSinceEpoch,
          lastModifiedTime.microsecondsSinceEpoch);
    },
    overrides: <Type, Generator>{
      Pub: () => TizenPub(
            fileSystem: globals.fs,
            logger: globals.logger,
            processManager: globals.processManager,
            usage: globals.flutterUsage,
            botDetector: globals.botDetector,
            platform: globals.platform,
          ),
    },
  );
}

/// Source: [_createProject] in 'create_test.dart'
Future<void> _createProject(
  Directory dir,
  List<String> createArgs,
  List<String> expectedPaths, {
  List<String> unexpectedPaths = const <String>[],
}) async {
  final TizenCreateCommand command = TizenCreateCommand();
  final CommandRunner<void> runner = createTestCommandRunner(command);
  await runner.run(<String>[
    'create',
    ...createArgs,
    dir.path,
  ]);

  bool pathExists(String path) {
    final String fullPath = globals.fs.path.join(dir.path, path);
    return globals.fs.typeSync(fullPath) != FileSystemEntityType.notFound;
  }

  final List<String> failures = <String>[
    for (final String path in expectedPaths)
      if (!pathExists(path)) 'Path "$path" does not exist.',
    for (final String path in unexpectedPaths)
      if (pathExists(path)) 'Path "$path" exists when it shouldn\'t.',
  ];
  expect(failures, isEmpty, reason: failures.join('\n'));
}
