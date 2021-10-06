// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/commands/create.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/net.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_http_client.dart';
import '../src/pubspec_schema.dart';
import '../src/test_flutter_command_runner.dart';

const String _kNoPlatformsMessage =
    "You've created a plugin project that doesn't yet support any platforms.";

void main() {
  Directory tempDir;
  Directory projectDir;
  BufferLogger logger;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    tempDir = globals.fs.systemTempDirectory.createTempSync();
    projectDir = tempDir.childDirectory('flutter_project');
    logger = BufferLogger.test();
  });

  testUsingContext('Can list samples', () async {
    final File outputFile = tempDir.childFile('flutter_samples.json');
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--list-samples',
      outputFile.path,
    ]);

    expect(outputFile, exists);
    expect(outputFile.readAsStringSync(), contains('sample1'));
  }, overrides: <Type, Generator>{
    HttpClientFactory: () {
      return () {
        return FakeHttpClient.list(<FakeRequest>[
          FakeRequest(
            Uri.parse('https://master-api.flutter.dev/snippets/index.json'),
            response: FakeResponse(body: utf8.encode('[{ "id": "sample1" }]')),
          ),
        ]);
      };
    },
  });

  testUsingContext('Can create a default project', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--no-pub',
      projectDir.path,
    ]);

    expect(projectDir.childDirectory('lib').childFile('main.dart'), exists);
    final Directory tizenDir = projectDir.childDirectory('tizen');
    expect(tizenDir.childDirectory('shared').listSync(), isNotEmpty);
    expect(tizenDir.childFile('.gitignore'), exists);
    expect(tizenDir.childFile('App.cs'), exists);
    expect(tizenDir.childFile('Runner.csproj'), exists);
    expect(tizenDir.childFile('tizen-manifest.xml'), exists);
  }, overrides: <Type, Generator>{});

  testUsingContext('Can create a C++ service app project', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--no-pub',
      '--platforms=tizen',
      '--template=app',
      '--app-type=service',
      '--tizen-language=cpp',
      projectDir.path,
    ]);

    expect(projectDir.childDirectory('lib').childFile('main.dart'), exists);
    final Directory tizenDir = projectDir.childDirectory('tizen');
    expect(tizenDir.childDirectory('inc').listSync(), isNotEmpty);
    expect(tizenDir.childDirectory('shared').listSync(), isNotEmpty);
    expect(tizenDir.childDirectory('src').listSync(), isNotEmpty);
    expect(tizenDir.childFile('.exportMap'), exists);
    expect(tizenDir.childFile('.gitignore'), exists);
    expect(tizenDir.childFile('project_def.prop'), exists);
    expect(tizenDir.childFile('tizen-manifest.xml'), exists);
  }, overrides: <Type, Generator>{});

  testUsingContext('Can create a plugin project', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--no-pub',
      '--platforms=tizen',
      '--template=plugin',
      projectDir.path,
    ]);

    validatePubspecForPlugin(
      projectDir: projectDir.path,
      expectedPlatforms: <String>['some_platform'],
      pluginClass: 'somePluginClass',
      unexpectedPlatforms: <String>['tizen'],
    );
    final Directory exampleDir = projectDir.childDirectory('example');
    expect(exampleDir.childDirectory('lib').childFile('main.dart'), exists);
    expect(exampleDir.childDirectory('tizen').listSync(), isNotEmpty);
    final Directory tizenDir = projectDir.childDirectory('tizen');
    expect(tizenDir.childDirectory('inc').listSync(), isNotEmpty);
    expect(tizenDir.childDirectory('src').listSync(), isNotEmpty);
    expect(tizenDir.childFile('.gitignore'), exists);
    expect(tizenDir.childFile('project_def.prop'), exists);
    expect(logger.errorText, contains(_kNoPlatformsMessage));
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });

  testUsingContext('Can add Tizen platform to existing plugin project',
      () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--no-pub',
      '--template=plugin',
      projectDir.path,
    ]);

    final Directory exampleDir = projectDir.childDirectory('example');
    expect(exampleDir.childDirectory('tizen'), isNot(exists));
    expect(projectDir.childDirectory('tizen'), isNot(exists));
    expect(logger.errorText, contains(_kNoPlatformsMessage));

    await runner.run(<String>[
      'create',
      '--no-pub',
      '--platforms=tizen',
      projectDir.path,
    ]);
    expect(exampleDir.childDirectory('tizen').listSync(), isNotEmpty);
    expect(projectDir.childDirectory('tizen').listSync(), isNotEmpty);
    expect(logger.statusText, isNot(contains(_kNoPlatformsMessage)));
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });
}
