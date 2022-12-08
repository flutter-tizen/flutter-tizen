// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/build_targets/plugins.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fake_tizen_sdk.dart';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late Logger logger;
  late Artifacts artifacts;
  late Cache cache;
  late Directory pluginDir;
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

    pluginDir = fileSystem.directory('/some_native_plugin');
    pluginDir.childFile('pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
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
    pluginDir
        .childFile('tizen/inc/some_native_plugin.h')
        .createSync(recursive: true);

    projectDir = fileSystem.directory('/flutter_project');
    projectDir.childFile('pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
dependencies:
  some_native_plugin:
    path: ${pluginDir.path}
''');
    projectDir.childFile('.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "some_native_plugin",
      "rootUri": "${pluginDir.uri}",
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

    _installFakeEngineArtifacts(cache.getArtifactDirectory('engine'));
  });

  testUsingContext('Can build staticLib project', () async {
    final Environment environment = Environment.test(
      projectDir,
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );

    await NativePlugins(const TizenBuildInfo(
      BuildInfo.debug,
      targetArch: 'x86',
      deviceProfile: 'wearable',
    )).build(environment);

    final Directory outputDir =
        environment.buildDir.childDirectory('tizen_plugins');
    expect(outputDir.childFile('include/some_native_plugin.h'), exists);
    expect(outputDir.childFile('lib/libflutter_plugins.so'), exists);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Cache: () => cache,
    TizenSdk: () => FakeTizenSdk(fileSystem),
  });

  testUsingContext('Can build sharedLib project', () async {
    final File projectDef = pluginDir.childFile('tizen/project_def.prop');
    projectDef.writeAsStringSync(
        projectDef.readAsStringSync().replaceFirst('staticLib', 'sharedLib'));

    final Environment environment = Environment.test(
      projectDir,
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );
    pluginDir.childFile('tizen/lib/libshared.so').createSync(recursive: true);

    await NativePlugins(const TizenBuildInfo(
      BuildInfo.debug,
      targetArch: 'x86',
      deviceProfile: 'wearable',
    )).build(environment);

    final Directory outputDir =
        environment.buildDir.childDirectory('tizen_plugins');
    expect(outputDir.childFile('lib/libflutter_plugins.so'), isNot(exists));
    expect(outputDir.childFile('lib/libsome_native_plugin.so'), exists);
    expect(outputDir.childFile('lib/libshared.so'), exists);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Cache: () => cache,
    TizenSdk: () => FakeTizenSdk(fileSystem),
  });

  testUsingContext('Copies resource files recursively', () async {
    final Environment environment = Environment.test(
      projectDir,
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );
    pluginDir.childFile('tizen/res/a/b.txt').createSync(recursive: true);

    await NativePlugins(const TizenBuildInfo(
      BuildInfo.release,
      targetArch: 'arm',
      deviceProfile: 'common',
    )).build(environment);

    final Directory outputResDir = environment.buildDir
        .childDirectory('tizen_plugins/res/some_native_plugin');
    expect(outputResDir.childFile('a/b.txt'), exists);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Cache: () => cache,
    TizenSdk: () => FakeTizenSdk(fileSystem),
  });

  testUsingContext('Can link to user libraries', () async {
    final Environment environment = Environment.test(
      projectDir,
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );
    pluginDir.childFile('tizen/lib/libstatic.a').createSync(recursive: true);
    pluginDir.childFile('tizen/lib/libshared.so').createSync(recursive: true);

    await NativePlugins(const TizenBuildInfo(
      BuildInfo.release,
      targetArch: 'arm',
      deviceProfile: 'common',
    )).build(environment);

    final Directory outputDir =
        environment.buildDir.childDirectory('tizen_plugins');
    expect(outputDir.childFile('lib/libstatic.a'), isNot(exists));
    expect(outputDir.childFile('lib/libshared.so'), exists);

    final Map<String, String> projectDef =
        parseIniFile(outputDir.childFile('project_def.prop'));
    expect(
      projectDef['USER_LIBS'],
      contains('some_native_plugin static shared'),
    );
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Cache: () => cache,
    TizenSdk: () => FakeTizenSdk(fileSystem),
  });
}

void _installFakeEngineArtifacts(Directory engineArtifactDir) {
  for (final String directory in <String>[
    'tizen-common/cpp_client_wrapper/include',
    'tizen-common/public',
  ]) {
    engineArtifactDir.childDirectory(directory).createSync(recursive: true);
  }
}
