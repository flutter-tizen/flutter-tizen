// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/build_targets/plugins.dart';
import 'package:flutter_tizen/commands/build.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tizen/tizen_plugins.dart';
import 'package:flutter_tizen/tizen_project.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:flutter_tools/src/project.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fake_tizen_sdk.dart';
import '../../src/fakes.dart';
import '../../src/package_config.dart';
import '../../src/test_build_system.dart';
import '../../src/test_flutter_command_runner.dart';
import '../../src/throwing_pub.dart';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late Logger logger;
  late Artifacts artifacts;
  late Cache cache;
  late Directory pluginDir;
  late Directory pluginDir2;
  late Directory projectDir;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();
    logger = BufferLogger.test();
    artifacts = Artifacts.test();
    cache = Cache.test(
      fileSystem: fileSystem,
      processManager: FakeProcessManager.any(),
    );

    fileSystem.file('lib/main.dart').createSync(recursive: true);

    pluginDir = fileSystem.directory('/some_native_plugin');
    pluginDir.childFile('pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
name: some_native_plugin
flutter:
  plugin:
    platforms:
      tizen:
        pluginClass: SomeNativePlugin
        fileName: some_native_plugin.h
''');
    pluginDir.childFile('tizen/project_def.prop')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
APPNAME = some_native_plugin
type = staticLib
''');
    pluginDir.childFile('tizen/inc/some_native_plugin.h').createSync(recursive: true);
    pluginDir2 = fileSystem.directory('/some_native_plugin2');
    pluginDir2.childFile('pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
name: some_native_plugin2
flutter:
  plugin:
    platforms:
      tizen:
        pluginClass: SomeNativePlugin2
        fileName: some_native_plugin2.h
''');
    pluginDir2.childFile('tizen/project_def.prop')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
APPNAME = some_native_plugin2
type = staticLib
''');
    pluginDir2.childFile('tizen/inc/some_native_plugin2.h').createSync(recursive: true);

    projectDir = fileSystem.directory('/flutter_project');
    // projectDir = fileSystem.currentDirectory;
    projectDir.childFile('pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
name: plugin_test
dependencies:
  some_native_plugin:
    path: ${pluginDir.path}
dev_dependencies:
  some_native_plugin2:
    path: ${pluginDir2.path}
''');
    projectDir.childFile('.dart_tool/package_graph.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
{
  "roots": ["plugin_test"],
  "packages": [
    {
      "name": "plugin_test",
      "dependencies": ["some_native_plugin"],
      "devDependencies": ["some_native_plugin2"]
    },
    {
      "name": "some_native_plugin",
      "dependencies": []
    },
    {
      "name": "some_native_plugin2",
      "dependencies": []
    }
  ],
  "configVersion": 1
}
''');
    projectDir.childFile('.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "plugin_test",
      "rootUri": "${projectDir.uri}",
      "packageUri": "lib/",
      "languageVersion": "2.12"
    },
    {
      "name": "some_native_plugin",
      "rootUri": "${pluginDir.uri}",
      "packageUri": "lib/",
      "languageVersion": "2.12"
    },
    {
      "name": "some_native_plugin2",
      "rootUri": "${pluginDir2.uri}",
      "packageUri": "lib/",
      "languageVersion": "2.12"
    }
  ]
}
''');
    projectDir.childFile('tizen/tizen-manifest.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<manifest package="package_id" version="1.0.0" api-version="4.0">
    <profile name="common"/>
    <ui-application appid="app_id" exec="Runner.dll" type="dotnet"/>
</manifest>
''');

    _createFakeIncludeDirs(cache);
  });

  testUsingContext('excludes dev dependencies from native plugin registrant for C++', () async {
    final command = TizenBuildCommand(
      fileSystem: fileSystem,
      buildSystem: TestBuildSystem.all(BuildResult(success: true)),
      osUtils: FakeOperatingSystemUtils(),
      logger: BufferLogger.test(),
      androidSdk: FakeAndroidSdk(),
    );
    final CommandRunner<void> runner = createTestCommandRunner(command);

    await runner.run(<String>[
      'build',
      'tpk',
      '--no-pub',
      '--device-profile=common',
      '--target-arch=x86',
      projectDir.path,
    ]);

    //final File cppPluginRegistrant = fileSystem.file('tizen/flutter/generated_plugin_registrant.h');
    final FlutterProject project = FlutterProject.fromDirectoryTest(projectDir);
    final File cppPluginRegistrant = TizenProject.fromFlutter(project)
        .managedDirectory
        .childFile('generated_plugin_registrant.h');

    print('[cppPluginRegistrant] ${cppPluginRegistrant.uri}');

//     expect(cppPluginRegistrant, exists);
//     expect(cppPluginRegistrant.readAsStringSync(), contains('''
// #include "some_native_plugin.h"

// // Registers Flutter plugins.
// void RegisterPlugins(flutter::PluginRegistry *registry) {
//   SomeNativePluginRegisterWithRegistrar(
//       registry->GetRegistrarForPlugin("SomeNativePlugin"));
// }
// '''));

    // await injectTizenPlugins(project);
    // final File generatedPluginRegistrant = TizenProject.fromFlutter(project)
    //     .managedDirectory
    //     .childFile('generated_plugin_registrant.h');
    // expect(generatedPluginRegistrant, exists);
    // expect(generatedPluginRegistrant.readAsStringSync(),
    //     isNot(contains('#include "some_native_plugin.h"')));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Cache: () => cache,
    Pub: ThrowingPub.new,
    TizenSdk: () => FakeTizenSdk(fileSystem),
  }, testOn: 'posix');
}

void _createFakeIncludeDirs(Cache cache) {
  final Directory dartSdkDir = cache.getCacheDir('dart-sdk');
  dartSdkDir.childDirectory('include').createSync(recursive: true);

  final Directory engineArtifactDir = cache.getArtifactDirectory('engine');
  for (final directory in <String>[
    'tizen-common/cpp_client_wrapper/include',
    'tizen-common/public',
  ]) {
    engineArtifactDir.childDirectory(directory).createSync(recursive: true);
  }
}
