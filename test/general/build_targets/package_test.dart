// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

const String kMsbuildOutput = '''
MSBuild version 17.3.0+92e077650 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Runner -> /flutter_project/tizen/bin/Release/tizen80/Runner.dll
  Configuration :
  Platform :
  TargetFramework :
  Runner is signed with Default Certificates!
  Runner -> /flutter_project/tizen/bin/Release/tizen80/package_id-1.0.0.tpk

Build succeeded.
    0 Warning(s)
    0 Error(s)
''';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late BufferLogger logger;
  late Artifacts artifacts;
  late Cache cache;
  late OperatingSystemUtils osUtils;
  late Directory projectDir;

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

  group('DotnetTpk', () {
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
          .childFile('tizen_plugins/lib/libflutter_plugins.so')
          .createSync(recursive: true);
      environment.buildDir
          .childFile('tizen_plugins/lib/libshared.so')
          .createSync(recursive: true);

      processManager.addCommand(FakeCommand(
        command: <String>[
          '/tizen-studio/tools/tizen-core/tz',
          'set',
          '-b',
          'Release',
          '-s',
          'test_profile',
          '-w',
          '${projectDir.path}/tizen',
        ],
        onRun: (_) {},
      ));

      processManager.addCommand(FakeCommand(
        command: <String>[
          '/tizen-studio/tools/tizen-core/tz',
          'build',
          '-w',
          '${projectDir.path}/tizen',
        ],
        onRun: (_) {
          projectDir
              .childFile('tizen/bin/Release/tizen80/package_id-1.0.0.tpk')
              .createSync(recursive: true);
        },
        stdout: kMsbuildOutput,
      ));

      await DotnetTpk(const TizenBuildInfo(
        BuildInfo.release,
        targetArch: 'arm',
        deviceProfile: 'common',
      )).build(environment);

      final File outputTpk = outputDir.childFile('package_id-1.0.0.tpk');
      expect(outputTpk, exists);

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
      TizenSdk: () => FakeTizenSdk(fileSystem,
          securityProfile: 'test_profile', processManager: processManager),
    });

    testUsingContext('Build fails if no security profile is found', () async {
      final Environment environment = Environment.test(
        projectDir,
        outputDir: projectDir.childDirectory('out'),
        fileSystem: fileSystem,
        logger: logger,
        artifacts: artifacts,
        processManager: processManager,
      );
      environment.buildDir
          .childDirectory('flutter_assets')
          .createSync(recursive: true);
      environment.buildDir.childFile('app.so').createSync(recursive: true);

      processManager.addCommand(FakeCommand(
        command: <String>[
          '/tizen-studio/tools/tizen-core/tz',
          'set',
          '-b',
          'Release',
          '-s',
          'test_profile',
          '-w',
          '${projectDir.path}/tizen',
        ],
        onRun: (_) {},
      ));

      processManager.addCommand(FakeCommand(
        command: <String>[
          '/tizen-studio/tools/tizen-core/tz',
          'build',
          '-w',
          '${projectDir.path}/tizen',
        ],
        onRun: (_) {
          projectDir
              .childFile('tizen/bin/Release/tizen80/package_id-1.0.0.tpk')
              .createSync(recursive: true);
        },
        stdout: kMsbuildOutput,
      ));

      await expectLater(
        () => DotnetTpk(const TizenBuildInfo(
          BuildInfo.release,
          targetArch: 'arm',
          deviceProfile: 'common',
        )).build(environment),
        throwsToolExit(message: 'No certificate profile found.'),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      OperatingSystemUtils: () => osUtils,
      TizenSdk: () => FakeTizenSdk(fileSystem, processManager: processManager),
    });
  });

  group('NativeTpk', () {
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
          .childFile('tizen_plugins/lib/libflutter_plugins.so')
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

      final Directory ephemeralDir =
          projectDir.childDirectory('tizen/flutter/ephemeral');
      final Directory flutterAssetsDir =
          ephemeralDir.childDirectory('res/flutter_assets');
      final File engineBinary =
          ephemeralDir.childFile('lib/libflutter_engine.so');
      final File embedder =
          ephemeralDir.childFile('lib/libflutter_tizen_common.so');
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
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      TizenSdk: () => FakeTizenSdk(fileSystem, securityProfile: 'test_profile'),
    });

    testUsingContext('Build fails if no security profile is found', () async {
      final Environment environment = Environment.test(
        projectDir,
        outputDir: projectDir.childDirectory('out'),
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
        throwsToolExit(message: 'No certificate profile found.'),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      TizenSdk: () => FakeTizenSdk(fileSystem),
    });
  });

  group('DotnetModule', () {
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
      projectDir
          .childFile('tizen/flutter/GeneratedPluginRegistrant.cs')
          .createSync(recursive: true);
      environment.buildDir
          .childFile('tizen_plugins/lib/libflutter_plugins.so')
          .createSync(recursive: true);

      await DotnetModule(const TizenBuildInfo(
        BuildInfo.release,
        targetArch: 'arm',
        deviceProfile: 'common',
      )).build(environment);

      final Directory flutterAssetsDir =
          outputDir.childDirectory('res/flutter_assets');
      final File engineBinary = outputDir.childFile('lib/libflutter_engine.so');
      final File embedder = outputDir.childFile('lib/libflutter_tizen.so');
      final File icuData = outputDir.childFile('res/icudtl.dat');
      final File aotSnapshot = outputDir.childFile('lib/libapp.so');
      final File generatedPluginRegistrant =
          outputDir.childFile('src/GeneratedPluginRegistrant.cs');
      final File pluginsLib = outputDir.childFile('lib/libflutter_plugins.so');

      expect(flutterAssetsDir, exists);
      expect(engineBinary, exists);
      expect(embedder, exists);
      expect(icuData, exists);
      expect(aotSnapshot, exists);
      expect(generatedPluginRegistrant, exists);
      expect(pluginsLib, exists);
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      TizenSdk: () => FakeTizenSdk(fileSystem, securityProfile: 'test_profile'),
    });
  });

  group('NativeModule', () {
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
      projectDir
          .childFile('tizen/flutter/generated_plugin_registrant.h')
          .createSync(recursive: true);
      environment.buildDir
          .childFile('tizen_plugins/lib/libflutter_plugins.so')
          .createSync(recursive: true);
      environment.buildDir
          .childFile('tizen_embedding/include/flutter.h')
          .createSync(recursive: true);
      environment.buildDir
          .childFile('tizen_embedding/libembedding_cpp.a')
          .createSync(recursive: true);

      await NativeModule(const TizenBuildInfo(
        BuildInfo.release,
        targetArch: 'arm',
        deviceProfile: 'common',
      )).build(environment);

      final Directory flutterAssetsDir =
          outputDir.childDirectory('res/flutter_assets');
      final File engineBinary = outputDir.childFile('lib/libflutter_engine.so');
      final File embedder =
          outputDir.childFile('lib/libflutter_tizen_common.so');
      final File icuData = outputDir.childFile('res/icudtl.dat');
      final File aotSnapshot = outputDir.childFile('lib/libapp.so');
      final File generatedPluginRegistrant =
          outputDir.childFile('inc/generated_plugin_registrant.h');
      final File pluginsLib = outputDir.childFile('lib/libflutter_plugins.so');
      final File embeddingHeader = outputDir.childFile('inc/flutter.h');
      final File embeddingLib =
          outputDir.childFile('Release/libembedding_cpp.a');

      expect(flutterAssetsDir, exists);
      expect(engineBinary, exists);
      expect(embedder, exists);
      expect(icuData, exists);
      expect(aotSnapshot, exists);
      expect(generatedPluginRegistrant, exists);
      expect(pluginsLib, exists);
      expect(embeddingHeader, exists);
      expect(embeddingLib, exists);
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
      Cache: () => cache,
      TizenSdk: () => FakeTizenSdk(fileSystem, securityProfile: 'test_profile'),
    });
  });
}

void _installFakeEngineArtifacts(Directory engineArtifactDir) {
  for (final String directory in <String>[
    'tizen-common/cpp_client_wrapper/include',
    'tizen-common/public',
  ]) {
    engineArtifactDir.childDirectory(directory).createSync(recursive: true);
  }
  for (final String file in <String>[
    'tizen-arm/6.0/libflutter_tizen_common.so',
    'tizen-arm-debug/icudtl.dat',
    'tizen-arm-debug/libflutter_engine.so',
    'tizen-arm-release/icudtl.dat',
    'tizen-arm-release/libflutter_engine.so',
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
