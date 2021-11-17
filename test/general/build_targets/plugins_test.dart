// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

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
import '../../src/fake_process_manager.dart';
import '../../src/fake_tizen_sdk.dart';
import '../../src/test_flutter_command_runner.dart';

void main() {
  FileSystem fileSystem;
  FakeProcessManager processManager;
  Logger logger;
  Artifacts artifacts;
  Directory pluginDir;
  Directory projectDir;
  Cache cache;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();
    logger = BufferLogger.test();
    artifacts = Artifacts.test();

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
    pluginDir.childFile('tizen/project_def.prop').createSync(recursive: true);
    pluginDir
        .childFile('tizen/inc/some_native_plugin.h')
        .createSync(recursive: true);

    projectDir = fileSystem.directory('/project');
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
      "name": "some_dart_plugin",
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

    cache = Cache.test(
      fileSystem: fileSystem,
      processManager: FakeProcessManager.any(),
    );
    final Directory engineArtifactDir = cache.getArtifactDirectory('engine');
    engineArtifactDir
        .childDirectory('tizen-common/cpp_client_wrapper')
        .createSync(recursive: true);
    engineArtifactDir
        .childDirectory('tizen-common/public')
        .createSync(recursive: true);
  });

  testUsingContext('Can build for debug x86', () async {
    final Environment environment = Environment.test(
      projectDir,
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );

    processManager.addCommand(FakeCommand(
      command: _tizenBuildCommand(
        'Debug',
        'x86',
        '/.tmp_rand0/rand0',
        predefine: 'WEARABLE_PROFILE',
        extraOptions: <String>[
          '-fPIC',
          '-I"cache/bin/cache/artifacts/engine/tizen-common/cpp_client_wrapper/include"',
          '-I"cache/bin/cache/artifacts/engine/tizen-common/public"',
        ],
      ),
      onRun: () {
        fileSystem
            .file('/.tmp_rand0/rand0/Debug/libsome_native_plugin.a')
            .createSync(recursive: true);
      },
    ));
    processManager.addCommand(FakeCommand(
      command: _tizenBuildCommand(
        'Debug',
        'x86',
        '/.tmp_rand0/rand1',
        extraOptions: <String>[
          '-lflutter_tizen_wearable',
          '-L"cache/bin/cache/artifacts/engine/tizen-x86-debug"',
          '-I"cache/bin/cache/artifacts/engine/tizen-common/public"',
          '-L"/project/build/2ca1f4ebdc59348ffdc31d97a51a98d5/tizen_plugins/lib"',
          '-Wl,--undefined=SomeNativePluginRegisterWithRegistrar',
        ],
      ),
      onRun: () => fileSystem
          .file('/.tmp_rand0/rand1/Debug/libflutter_plugins.so')
          .createSync(recursive: true),
    ));

    await NativePlugins(const TizenBuildInfo(
      BuildInfo.debug,
      targetArch: 'x86',
      deviceProfile: 'wearable',
    )).build(environment);

    final File outputLib =
        environment.buildDir.childFile('tizen_plugins/libflutter_plugins.so');
    expect(outputLib, exists);
    expect(processManager, hasNoRemainingExpectations);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Cache: () => cache,
    TizenSdk: () => FakeTizenSdk(fileSystem, processManager: processManager),
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

    processManager.addCommand(FakeCommand(
      command: _tizenBuildCommand(
        'Release',
        'arm',
        '/.tmp_rand0/rand0',
        predefine: 'COMMON_PROFILE',
        extraOptions: <String>[
          '-fPIC',
          '-I"cache/bin/cache/artifacts/engine/tizen-common/cpp_client_wrapper/include"',
          '-I"cache/bin/cache/artifacts/engine/tizen-common/public"',
        ],
      ),
      onRun: () {
        fileSystem
            .file('/.tmp_rand0/rand0/Release/libsome_native_plugin.a')
            .createSync(recursive: true);
      },
    ));
    processManager.addCommand(FakeCommand(
      command: _tizenBuildCommand(
        'Release',
        'arm',
        '/.tmp_rand0/rand1',
        extraOptions: <String>[
          '-lflutter_tizen_common',
          '-L"cache/bin/cache/artifacts/engine/tizen-arm-release"',
          '-I"cache/bin/cache/artifacts/engine/tizen-common/public"',
          '-L"/project/build/2ca1f4ebdc59348ffdc31d97a51a98d5/tizen_plugins/lib"',
          '-Wl,--undefined=SomeNativePluginRegisterWithRegistrar',
        ],
      ),
      onRun: () => fileSystem
          .file('/.tmp_rand0/rand1/Release/libflutter_plugins.so')
          .createSync(recursive: true),
    ));

    await NativePlugins(const TizenBuildInfo(
      BuildInfo.release,
      targetArch: 'arm',
      deviceProfile: 'common',
    )).build(environment);

    final Directory rootDir =
        environment.buildDir.childDirectory('tizen_plugins');
    expect(
      rootDir.childFile('project_def.prop').readAsStringSync(),
      contains('USER_LIBS = pthread some_native_plugin static shared'),
    );
    expect(rootDir.childFile('lib/libstatic.a'), isNot(exists));
    expect(rootDir.childFile('lib/libshared.so'), exists);
    expect(processManager, hasNoRemainingExpectations);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Cache: () => cache,
    TizenSdk: () => FakeTizenSdk(fileSystem, processManager: processManager),
  });
}

List<String> _tizenBuildCommand(
  String buildMode,
  String arch,
  String workingDir, {
  String predefine,
  List<String> extraOptions,
}) {
  return <String>[
    '/tizen-studio/tools/ide/bin/tizen',
    'build-native',
    '-C',
    buildMode,
    '-a',
    arch,
    '-c',
    'llvm-10.0',
    if (predefine != null) ...<String>['-d', predefine],
    if (extraOptions.isNotEmpty) ...<String>['-e', extraOptions.join(' ')],
    '-r',
    'rootstrap',
    '--',
    workingDir,
  ];
}
