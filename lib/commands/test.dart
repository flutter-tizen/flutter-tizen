// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:file/file.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/test.dart';
import 'package:flutter_tools/src/dart/language_version.dart';
import 'package:flutter_tools/src/dart/package_map.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/test/runner.dart';
import 'package:flutter_tools/src/test/test_wrapper.dart';
import 'package:package_config/package_config.dart';
import 'package:test_core/src/executable.dart' as test;
import 'package:test_core/src/platform.dart' as hack
    show registerPlatformPlugin;

import '../tizen_cache.dart';
import '../tizen_plugins.dart';
import '../tizen_project.dart';

class TizenTestCommand extends TestCommand
    with TizenExtension, TizenRequiredArtifacts {
  TizenTestCommand({
    bool verboseHelp = false,
    TestWrapper testWrapper = const TestWrapper(),
    FlutterTestRunner testRunner = const FlutterTestRunner(),
  }) : super(
          verboseHelp: verboseHelp,
          testWrapper: testWrapper,
          testRunner: testRunner,
        );

  @override
  Future<FlutterCommandResult> runCommand() {
    // ignore: invalid_use_of_visible_for_testing_member
    if (isIntegrationTest && testWrapper is TizenTestWrapper) {
      (testWrapper as TizenTestWrapper).setIntegrationTestMode();
    }
    return super.runCommand();
  }
}

/// See: [TestWrapper] in `test_wrapper.dart`
class TizenTestWrapper implements TestWrapper {
  bool _isIntegrationTest = false;

  void setIntegrationTestMode() => _isIntegrationTest = true;

  @override
  Future<void> main(List<String> args) async {
    if (!_isIntegrationTest) {
      await test.main(args);
      return;
    }
    
    final int filesOptionIndex = args.lastIndexOf('--');
    final List<String> newArgs = args.sublist(0, filesOptionIndex + 1);
    final List<File> testFiles = args
        .sublist(filesOptionIndex + 1)
        .map((String path) => globals.fs.file(path))
        .toList();
    final FlutterProject flutterProject = FlutterProject.current();
    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
      flutterProject.directory.childFile('.packages'),
      logger: globals.logger,
    );
    final File pluginRegistrant = TizenProject.fromFlutter(flutterProject)
        .managedDirectory
        .childFile('generated_plugin_registrant.dart');

    final Directory runnerDir = globals.fs.systemTempDirectory.createTempSync();
    for (final File testFile in testFiles) {
      final File runnerFile = runnerDir.childFile(
          testFile.basename.replaceFirst('_test.dart', '_test_runner.dart'))
        ..createSync(recursive: true);

      final LanguageVersion languageVersion = determineLanguageVersion(
        testFile,
        packageConfig[flutterProject.manifest.appName],
        Cache.flutterRoot,
      );
      runnerFile.writeAsStringSync('''
//
// Generated file. Do not edit.
//
// @dart=${languageVersion.major}.${languageVersion.minor}

import '${testFile.absolute.path}' as entrypoint;
import '${pluginRegistrant.absolute.path}';

Future<void> main() async {
  registerPlugins();
  entrypoint.main();
}
''');
      newArgs.add(runnerFile.absolute.path.toString());
    }
    await test.main(newArgs);
  }

  /// Source: [TestWrapper.registerPlatformPlugin] in `test_wrapper.dart`.
  @override
  void registerPlatformPlugin(Iterable<Runtime> runtimes,
      FutureOr<PlatformPlugin> Function() platforms) {
    hack.registerPlatformPlugin(runtimes, platforms);
  }
}
