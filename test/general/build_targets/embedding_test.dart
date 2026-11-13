// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/build_targets/embedding.dart';
import 'package:flutter_tizen/build_targets/utils.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/dart/pub.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fake_tizen_sdk.dart';
import '../../src/throwing_pub.dart';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late Cache cache;

  setUpAll(() {
    Cache.flutterRoot = 'flutter';
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();
    cache = Cache.test(
      fileSystem: fileSystem,
      processManager: FakeProcessManager.any(),
    );

    final Directory embeddingDir = fileSystem.directory('embedding/cpp');
    embeddingDir.childFile('project_def.prop')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
APPNAME = embedding_cpp
type = staticLib
''');
    embeddingDir.childFile('include/flutter.h').createSync(recursive: true);

    _createFakeIncludeDirs(cache);
  });

  testUsingContext('x64 apps are built against API version 8.0 or higher', () {
    expect(getBuildApiVersion('6.0', 'x64'), '8.0');
    expect(getBuildApiVersion(null, 'x64'), '8.0');
    expect(getBuildApiVersion('9.0', 'x64'), '9.0');
    expect(getBuildApiVersion('6.0', 'arm'), '6.0');
  });

  testUsingContext('Build succeeds', () async {
    final environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: BufferLogger.test(),
      artifacts: Artifacts.test(),
      processManager: processManager,
    );

    await NativeEmbedding(const TizenBuildInfo(
      BuildInfo.release,
      targetArch: 'arm',
      deviceProfile: 'common',
    )).build(environment);

    final Directory outputDir = environment.buildDir.childDirectory('tizen_embedding');
    expect(outputDir.childFile('include/flutter.h'), exists);
    expect(outputDir.childFile('libembedding_cpp.a'), exists);
    // The shared source directory is not used as a build directory.
    expect(fileSystem.directory('embedding/cpp/Release'), isNot(exists));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Cache: () => cache,
    TizenSdk: () => FakeTizenSdk(fileSystem),
  });

  group('Native app', () {
    late Directory projectDir;

    setUp(() {
      projectDir = fileSystem.currentDirectory;
      projectDir.childFile('tizen/tizen-manifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
<manifest package="package_id" version="1.0.0" api-version="6.0">
    <profile name="common"/>
    <ui-application appid="app_id" exec="runner" type="flutter"/>
</manifest>
''');
      projectDir.childFile('pubspec.yaml').writeAsStringSync('name: native_app\n');
      _writePackageConfig(projectDir, <String, Directory>{});
    });

    Future<Directory> build() async {
      final environment = Environment.test(
        projectDir,
        fileSystem: fileSystem,
        logger: BufferLogger.test(),
        artifacts: Artifacts.test(),
        processManager: processManager,
      );
      environment.buildDir.createSync(recursive: true);
      await NativeEmbedding(const TizenBuildInfo(
        BuildInfo.release,
        targetArch: 'arm',
        deviceProfile: 'common',
      )).build(environment);
      return environment.buildDir;
    }

    testUsingContext('Skips the build if the app has no C++ plugins', () async {
      final Directory buildDir = await build();
      expect(buildDir.childDirectory('tizen_embedding'), isNot(exists));
      expect(buildDir.childFile('tizen_embedding.d'), exists);
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      TizenSdk: () => FakeTizenSdk(fileSystem),
      Pub: ThrowingPub.new,
    });

    testUsingContext('Builds if the app has a C++ plugin', () async {
      final Directory pluginDir = fileSystem.directory('/some_native_plugin');
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
      projectDir.childFile('pubspec.yaml').writeAsStringSync('''
name: native_app
dependencies:
  some_native_plugin:
    path: ${pluginDir.path}
''');
      _writePackageConfig(projectDir, <String, Directory>{'some_native_plugin': pluginDir});

      final Directory buildDir = await build();
      expect(buildDir.childFile('tizen_embedding/libembedding_cpp.a'), exists);
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      TizenSdk: () => FakeTizenSdk(fileSystem),
      Pub: ThrowingPub.new,
    });
  });
}

void _writePackageConfig(Directory projectDir, Map<String, Directory> dependencies) {
  final graphPackages = <String>[
    '{"name": "native_app", "dependencies": [${dependencies.keys.map((String name) => '"$name"').join(', ')}]}',
    for (final String name in dependencies.keys) '{"name": "$name", "dependencies": []}',
  ];
  projectDir.childFile('.dart_tool/package_graph.json')
    ..createSync(recursive: true)
    ..writeAsStringSync('''
{
  "roots": ["native_app"],
  "packages": [${graphPackages.join(', ')}],
  "configVersion": 1
}
''');
  final configPackages = <String>[
    '{"name": "native_app", "rootUri": "${projectDir.uri}", "packageUri": "lib/", "languageVersion": "2.12"}',
    for (final MapEntry<String, Directory> entry in dependencies.entries)
      '{"name": "${entry.key}", "rootUri": "${entry.value.uri}", "packageUri": "lib/", "languageVersion": "2.12"}',
  ];
  projectDir.childFile('.dart_tool/package_config.json')
    ..createSync(recursive: true)
    ..writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [${configPackages.join(', ')}]
}
''');
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
