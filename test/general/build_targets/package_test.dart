// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/build_targets/package.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:test/fake.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fake_process_manager.dart';
import '../../src/fake_tizen_sdk.dart';

void main() {
  FileSystem fileSystem;
  FakeProcessManager processManager;
  BufferLogger logger;
  Artifacts artifacts;
  Cache cache;
  OperatingSystemUtils osUtils;
  Directory projectDir;

  setUpAll(() {
    Cache.disableLocking();
    Cache.flutterRoot = 'flutter';
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
    osUtils = _FakeOperatingSystemUtils(fileSystem);

    projectDir = fileSystem.directory('/flutter_project');
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

  group('.NET TPK', () {
    testUsingContext('Build succeeds', () async {
      final Directory outputDir = projectDir.childDirectory('out');
      final Environment environment = Environment.test(
        projectDir,
        outputDir: outputDir,
        fileSystem: fileSystem,
        logger: logger,
        artifacts: artifacts,
        processManager: processManager,
      );
      environment.buildDir
          .childDirectory('flutter_assets')
          .createSync(recursive: true);
      environment.buildDir.childFile('app.so').createSync(recursive: true);
      environment.buildDir
          .childFile('tizen_plugins/libflutter_plugins.so')
          .createSync(recursive: true);
      environment.buildDir
          .childFile('tizen_plugins/lib/libshared.so')
          .createSync(recursive: true);

      processManager.addCommand(FakeCommand(
        command: <String>[
          'dotnet',
          'build',
          '-c',
          'Release',
          '-o',
          '${outputDir.path}/',
          '/p:DefineConstants=COMMON_PROFILE',
          '${projectDir.path}/tizen',
        ],
        onRun: () {
          outputDir
              .childFile('package_id-1.0.0.tpk')
              .createSync(recursive: true);
        },
      ));

      await DotnetTpk(const TizenBuildInfo(
        BuildInfo.release,
        targetArch: 'arm',
        deviceProfile: 'common',
      )).build(environment);

      final Directory ephemeralDir =
          projectDir.childDirectory('tizen/flutter/ephemeral');
      final Directory flutterAssetsDir =
          ephemeralDir.childDirectory('res/flutter_assets');
      final File engineBinary =
          ephemeralDir.childFile('lib/libflutter_engine.so');
      final File embedder = ephemeralDir.childFile('lib/libflutter_tizen.so');
      final File icuData = ephemeralDir.childFile('res/icudtl.dat');
      final File aotSnapshot = ephemeralDir.childFile('lib/libapp.so');
      final File pluginsLib =
          ephemeralDir.childFile('lib/libflutter_plugins.so');
      final File pluginsUserLib = ephemeralDir.childFile('lib/libshared.so');

      expect(flutterAssetsDir, exists);
      expect(engineBinary, exists);
      expect(embedder, exists);
      expect(icuData, exists);
      expect(aotSnapshot, exists);
      expect(pluginsLib, exists);
      expect(pluginsUserLib, exists);

      expect(processManager, hasNoRemainingExpectations);
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      OperatingSystemUtils: () => osUtils,
      TizenSdk: () => FakeTizenSdk(fileSystem, securityProfile: 'test_profile'),
    });

    testUsingContext(
        'Use the default certificate if no security profile is found',
        () async {
      final Directory outputDir = projectDir.childDirectory('out');
      final Environment environment = Environment.test(
        projectDir,
        outputDir: outputDir,
        fileSystem: fileSystem,
        logger: logger,
        artifacts: artifacts,
        processManager: processManager,
      );
      environment.buildDir
          .childDirectory('flutter_assets')
          .createSync(recursive: true);

      processManager.addCommand(FakeCommand(
        command: <String>[
          'dotnet',
          'build',
          '-c',
          'Debug',
          '-o',
          '${outputDir.path}/',
          '/p:DefineConstants=COMMON_PROFILE',
          '${projectDir.path}/tizen',
        ],
        onRun: () {
          outputDir
              .childFile('package_id-1.0.0.tpk')
              .createSync(recursive: true);
        },
      ));

      await DotnetTpk(const TizenBuildInfo(
        BuildInfo.debug,
        targetArch: 'arm',
        deviceProfile: 'common',
      )).build(environment);

      expect(
        logger.statusText,
        contains('The TPK was signed with the default certificate.'),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      OperatingSystemUtils: () => osUtils,
      TizenSdk: () => FakeTizenSdk(fileSystem),
    });
  });

  group('Native TPK', () {
    setUp(() {
      projectDir.childFile('tizen/project_def.prop')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
APPNAME = runner
type = app
''');
    });

    testUsingContext('Build succeeds', () async {
      final Directory outputDir = projectDir.childDirectory('out');
      final Environment environment = Environment.test(
        projectDir,
        outputDir: outputDir,
        fileSystem: fileSystem,
        logger: logger,
        artifacts: artifacts,
        processManager: processManager,
      );
      environment.buildDir
          .childDirectory('flutter_assets')
          .createSync(recursive: true);
      environment.buildDir.childFile('app.so').createSync(recursive: true);
      environment.buildDir
          .childFile('tizen_plugins/libflutter_plugins.so')
          .createSync(recursive: true);
      environment.buildDir
          .childFile('tizen_plugins/lib/libshared.so')
          .createSync(recursive: true);

      await NativeTpk(const TizenBuildInfo(
        BuildInfo.release,
        targetArch: 'arm',
        deviceProfile: 'common',
      )).build(environment);

      final File outputTpk = outputDir.childFile('package_id-1.0.0.tpk');
      expect(outputTpk, exists);

      final Directory tizenDir = projectDir.childDirectory('tizen');
      final Directory flutterAssetsDir =
          tizenDir.childDirectory('res/flutter_assets');
      final File engineBinary = tizenDir.childFile('lib/libflutter_engine.so');
      final File embedder =
          tizenDir.childFile('lib/libflutter_tizen_common.so');
      final File icuData = tizenDir.childFile('res/icudtl.dat');
      final File aotSnapshot = tizenDir.childFile('lib/libapp.so');
      final File pluginsLib = tizenDir.childFile('lib/libflutter_plugins.so');
      final File pluginsUserLib = tizenDir.childFile('lib/libshared.so');

      expect(flutterAssetsDir, exists);
      expect(engineBinary, exists);
      expect(embedder, exists);
      expect(icuData, exists);
      expect(aotSnapshot, exists);
      expect(pluginsLib, exists);
      expect(pluginsUserLib, exists);
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      TizenSdk: () => FakeTizenSdk(fileSystem, securityProfile: 'test_profile'),
    });

    testUsingContext('Build fails if no security profile is found', () async {
      final Directory outputDir = projectDir.childDirectory('out');
      final Environment environment = Environment.test(
        projectDir,
        outputDir: outputDir,
        fileSystem: fileSystem,
        logger: logger,
        artifacts: artifacts,
        processManager: processManager,
      );
      environment.buildDir
          .childDirectory('flutter_assets')
          .createSync(recursive: true);

      await expectLater(
        () => NativeTpk(const TizenBuildInfo(
          BuildInfo.debug,
          targetArch: 'arm',
          deviceProfile: 'common',
        )).build(environment),
        throwsToolExit(
          message: 'Native TPKs cannot be built without a valid certificate.',
        ),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      TizenSdk: () => FakeTizenSdk(fileSystem),
    });
  });
}

void _installFakeEngineArtifacts(Directory engineArtifactDir) {
  for (final String directory in <String>[
    'tizen-common/cpp_client_wrapper',
    'tizen-common/public',
  ]) {
    engineArtifactDir.childDirectory(directory).createSync(recursive: true);
  }
  for (final String file in <String>[
    'tizen-common/icu/icudtl.dat',
    'tizen-arm-debug/libflutter_engine.so',
    'tizen-arm-debug/libflutter_tizen_common.so',
    'tizen-arm-release/libflutter_engine.so',
    'tizen-arm-release/libflutter_tizen_common.so',
  ]) {
    engineArtifactDir.childFile(file).createSync(recursive: true);
  }
}

class _FakeOperatingSystemUtils extends Fake implements OperatingSystemUtils {
  _FakeOperatingSystemUtils(this._fileSystem);

  final FileSystem _fileSystem;

  @override
  File which(String execName) => _fileSystem.file(execName)..createSync();
}
