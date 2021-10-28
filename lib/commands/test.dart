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
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/test/runner.dart';
import 'package:flutter_tools/src/test/test_wrapper.dart';
import 'package:flutter_tools/src/test/watcher.dart';
import 'package:package_config/package_config.dart';

import '../tizen_cache.dart';
import '../tizen_plugins.dart';

class TizenTestCommand extends TestCommand with TizenRequiredArtifacts {
  TizenTestCommand({
    bool verboseHelp = false,
    TestWrapper testWrapper = const TestWrapper(),
    FlutterTestRunner testRunner,
  }) : super(
          verboseHelp: verboseHelp,
          testWrapper: testWrapper,
          testRunner: testRunner ?? TizenTestRunner(),
        );

  @override
  Future<FlutterCommandResult> runCommand() {
    if (testRunner is TizenTestRunner) {
      // ignore: invalid_use_of_visible_for_testing_member
      (testRunner as TizenTestRunner).isIntegrationTest = isIntegrationTest;
    }
    return super.runCommand();
  }
}

class TizenTestRunner implements FlutterTestRunner {
  TizenTestRunner();

  final FlutterTestRunner testRunner = const FlutterTestRunner();

  bool isIntegrationTest = false;

  /// See: [_generateEntrypointWithPluginRegistrant] in `tizen_plugins.dart`
  Stream<String> _generateEntrypointWrappers(List<String> testFiles) async* {
    final FlutterProject project = FlutterProject.current();
    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
      project.packageConfigFile,
      logger: globals.logger,
    );
    final List<TizenPlugin> dartPlugins =
        await findTizenPlugins(project, dartOnly: true);
    final Directory runnerDir = globals.fs.systemTempDirectory.createTempSync();

    for (final File testFile
        in testFiles.map((String path) => globals.fs.file(path))) {
      final Uri testFileUri = testFile.absolute.uri;
      final LanguageVersion languageVersion = determineLanguageVersion(
        testFile,
        packageConfig.packageOf(testFileUri),
        Cache.flutterRoot,
      );
      final Map<String, Object> context = <String, Object>{
        'mainImport': testFileUri.toString(),
        'dartLanguageVersion': languageVersion.toString(),
        'plugins': dartPlugins.map((TizenPlugin plugin) => plugin.toMap()),
      };
      final File newTestFile = runnerDir.childFile(testFile.basename);
      renderTemplateToFile(
        '''
//
// Generated file. Do not edit.
//
// @dart = {{dartLanguageVersion}}

import '{{mainImport}}' as entrypoint;
{{#plugins}}
import 'package:{{name}}/{{name}}.dart';
{{/plugins}}

void main() {
{{#plugins}}
  {{dartPluginClass}}.register();
{{/plugins}}
  entrypoint.main();
}
''',
        context,
        newTestFile,
      );
      yield newTestFile.absolute.path;
    }
  }

  @override
  Future<int> runTests(
    TestWrapper testWrapper,
    List<String> testFiles, {
    DebuggingOptions debuggingOptions,
    List<String> names = const <String>[],
    List<String> plainNames = const <String>[],
    String tags,
    String excludeTags,
    bool enableObservatory = false,
    bool ipv6 = false,
    bool machine = false,
    String precompiledDillPath,
    Map<String, String> precompiledDillFiles,
    bool updateGoldens = false,
    TestWatcher watcher,
    int concurrency,
    bool buildTestAssets = false,
    FlutterProject flutterProject,
    String icudtlPath,
    Directory coverageDirectory,
    bool web = false,
    String randomSeed,
    String reporter,
    String timeout,
    bool runSkipped = false,
    int shardIndex,
    int totalShards,
    Device integrationTestDevice,
    String integrationTestUserIdentifier,
  }) async {
    if (isIntegrationTest) {
      testFiles = await _generateEntrypointWrappers(testFiles).toList();
    }
    return testRunner.runTests(
      testWrapper,
      testFiles,
      debuggingOptions: debuggingOptions,
      names: names,
      plainNames: plainNames,
      tags: tags,
      excludeTags: excludeTags,
      enableObservatory: enableObservatory,
      ipv6: ipv6,
      machine: machine,
      precompiledDillPath: precompiledDillPath,
      precompiledDillFiles: precompiledDillFiles,
      updateGoldens: updateGoldens,
      watcher: watcher,
      concurrency: concurrency,
      buildTestAssets: buildTestAssets,
      flutterProject: flutterProject,
      icudtlPath: icudtlPath,
      coverageDirectory: coverageDirectory,
      web: web,
      randomSeed: randomSeed,
      reporter: reporter,
      timeout: timeout,
      runSkipped: runSkipped,
      shardIndex: shardIndex,
      totalShards: totalShards,
      integrationTestDevice: integrationTestDevice,
      integrationTestUserIdentifier: integrationTestUserIdentifier,
    );
  }
}
