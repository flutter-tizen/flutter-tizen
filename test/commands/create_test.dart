// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/commands/create.dart';
import 'package:flutter_tizen/tizen_pub.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/net.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:pubspec_parse/pubspec_parse.dart';

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

    expect(projectDir.childFile('lib/main.dart'), exists);
    expect(projectDir.childDirectory('tizen/shared').listSync(), isNotEmpty);
    expect(projectDir.childFile('tizen/.gitignore'), exists);
    expect(projectDir.childFile('tizen/App.cs'), exists);
    expect(projectDir.childFile('tizen/Runner.csproj'), exists);
    expect(projectDir.childFile('tizen/tizen-manifest.xml'), exists);
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

    expect(projectDir.childFile('lib/main.dart'), exists);
    expect(projectDir.childDirectory('tizen/inc').listSync(), isNotEmpty);
    expect(projectDir.childDirectory('tizen/shared').listSync(), isNotEmpty);
    expect(projectDir.childDirectory('tizen/src').listSync(), isNotEmpty);
    expect(projectDir.childFile('tizen/.exportMap'), exists);
    expect(projectDir.childFile('tizen/.gitignore'), exists);
    expect(projectDir.childFile('tizen/project_def.prop'), exists);
    expect(projectDir.childFile('tizen/tizen-manifest.xml'), exists);
  }, overrides: <Type, Generator>{});

  testUsingContext('Cannot create a C# multi app project', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await expectLater(
      () => runner.run(<String>[
        'create',
        '--no-pub',
        '--platforms=tizen',
        '--app-type=multi',
        projectDir.path,
      ]),
      throwsToolExit(message: 'Could not locate a template:'),
    );
  }, overrides: <Type, Generator>{});

  testUsingContext('Can create a C++ multi app project', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--no-pub',
      '--platforms=tizen',
      '--app-type=multi',
      '--tizen-language=cpp',
      projectDir.path,
    ]);

    final File mainDart = projectDir.childFile('lib/main.dart');
    expect(mainDart.readAsStringSync(), contains('Tizen Multi App Demo'));

    final String rawPubspec =
        projectDir.childFile('pubspec.yaml').readAsStringSync();
    final Pubspec pubspec = Pubspec.parse(rawPubspec);
    expect(pubspec.dependencies, contains('tizen_app_control'));
    expect(pubspec.dependencies, contains('messageport_tizen'));

    expect(projectDir.childDirectory('tizen/ui').listSync(), isNotEmpty);
    expect(projectDir.childDirectory('tizen/service').listSync(), isNotEmpty);

    final ProcessResult result = await Process.run(
      'git',
      <String>['diff', '--name-only'],
      workingDirectory: Cache.flutterRoot,
    );
    expect(result.exitCode, 0);
    expect(result.stdout, isEmpty);
  }, overrides: <Type, Generator>{});

  testUsingContext('Can create a C++ plugin project', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--no-pub',
      '--platforms=tizen',
      '--template=plugin',
      '--tizen-language=cpp',
      projectDir.path,
    ]);

    validatePubspecForPlugin(
      projectDir: projectDir.path,
      expectedPlatforms: <String>['some_platform'],
      pluginClass: 'somePluginClass',
      unexpectedPlatforms: <String>['tizen'],
    );

    expect(projectDir.childFile('example/lib/main.dart'), exists);
    expect(projectDir.childFile('example/tizen/Runner.csproj'), exists);
    expect(projectDir.childDirectory('tizen/inc').listSync(), isNotEmpty);
    expect(projectDir.childDirectory('tizen/src').listSync(), isNotEmpty);
    expect(projectDir.childFile('tizen/.gitignore'), exists);
    expect(projectDir.childFile('tizen/project_def.prop'), exists);
    expect(logger.errorText, contains(_kNoPlatformsMessage));
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });

  testUsingContext('Can create a C# plugin project', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--no-pub',
      '--platforms=tizen',
      '--template=plugin',
      '--tizen-language=csharp',
      projectDir.path,
    ]);

    validatePubspecForPlugin(
      projectDir: projectDir.path,
      expectedPlatforms: <String>['some_platform'],
      pluginClass: 'somePluginClass',
      unexpectedPlatforms: <String>['tizen'],
    );

    expect(projectDir.childFile('example/lib/main.dart'), exists);
    expect(projectDir.childFile('example/tizen/Runner.csproj'), exists);
    expect(projectDir.childFile('tizen/.gitignore'), exists);
    expect(projectDir.childFile('tizen/FlutterProjectPlugin.csproj'), exists);
    expect(
        projectDir.childFile('tizen/FlutterProjectPlugin.csproj.user'), exists);
    expect(logger.errorText, contains(_kNoPlatformsMessage));
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });

  testUsingContext(
      'Cannot create a plugin project with --app-type=multi option', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await expectLater(
      () => runner.run(<String>[
        'create',
        '--no-pub',
        '--platforms=tizen',
        '--template=plugin',
        '--app-type=multi',
        projectDir.path,
      ]),
      throwsToolExit(),
    );
  }, overrides: <Type, Generator>{});

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
    expect(projectDir.childDirectory('example/tizen'), isNot(exists));
    expect(projectDir.childDirectory('tizen'), isNot(exists));
    expect(logger.errorText, contains(_kNoPlatformsMessage));

    await runner.run(<String>[
      'create',
      '--no-pub',
      '--platforms=tizen',
      projectDir.path,
    ]);
    expect(projectDir.childDirectory('example/tizen').listSync(), isNotEmpty);
    expect(projectDir.childDirectory('tizen').listSync(), isNotEmpty);
    expect(logger.statusText, isNot(contains(_kNoPlatformsMessage)));
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });

  testUsingContext('Can create a C# module project', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--template=module',
      projectDir.path,
    ]);

    expect(projectDir.childFile('lib/main.dart'), exists);
    expect(projectDir.childFile('.tizen/Runner.csproj'), exists);
  }, overrides: <Type, Generator>{
    Pub: () => TizenPub(
          fileSystem: globals.fs,
          logger: globals.logger,
          processManager: globals.processManager,
          platform: globals.platform,
          botDetector: globals.botDetector,
          usage: globals.flutterUsage,
        ),
  });

  testUsingContext('Can create a C++ module project', () async {
    final TizenCreateCommand command = TizenCreateCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'create',
      '--template=module',
      '--tizen-language=cpp',
      projectDir.path,
    ]);

    expect(projectDir.childFile('lib/main.dart'), exists);
    expect(projectDir.childFile('.tizen/project_def.prop'), exists);
  }, overrides: <Type, Generator>{
    Pub: () => TizenPub(
          fileSystem: globals.fs,
          logger: globals.logger,
          processManager: globals.processManager,
          platform: globals.platform,
          botDetector: globals.botDetector,
          usage: globals.flutterUsage,
        ),
  });
}
