// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tizen/tizen_builder.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/base/analyze_size.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:unified_analytics/src/analytics.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_tizen_sdk.dart';
import '../src/test_build_system.dart';

const _kTizenManifestContents = '''
<manifest package="package_id" version="1.0.0" api-version="4.0">
    <profile name="common"/>
    <ui-application appid="app_id" exec="Runner.dll" type="dotnet"/>
</manifest>
''';

void main() {
  late FileSystem fileSystem;
  late BufferLogger logger;
  late Platform platform;
  late FlutterProject project;
  late TizenBuildInfo tizenBuildInfo;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.file('main.dart').createSync();
    fileSystem.file('pubspec.yaml').createSync();
    fileSystem.file('.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"configVersion": 2, "packages": []}');
    logger = BufferLogger.test();
    platform = FakePlatform(environment: <String, String>{'HOME': '/'});
    project = FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);

    tizenBuildInfo = const TizenBuildInfo(
      BuildInfo(
        BuildMode.release,
        null,
        trackWidgetCreation: true,
        treeShakeIcons: false,
        codeSizeDirectory: 'code_size_analysis',
        packageConfigPath: '.dart_tool/package_config.json',
      ),
      targetArch: 'arm',
      deviceProfile: 'common',
    );
  });

  group('TizenBuilder.buildTpk', () {
    testUsingContext('Build fails if there is no Tizen project', () async {
      await expectLater(
        () => TizenBuilder().buildTpk(
          project: project,
          tizenBuildInfo: tizenBuildInfo,
          targetFile: 'main.dart',
        ),
        throwsToolExit(message: 'This project is not configured for Tizen.'),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
    });

    testUsingContext('Build fails if Tizen Studio is not installed', () async {
      fileSystem.file('tizen/tizen-manifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(_kTizenManifestContents);

      await expectLater(
        () => TizenBuilder().buildTpk(
          project: project,
          tizenBuildInfo: tizenBuildInfo,
          targetFile: 'main.dart',
        ),
        throwsToolExit(message: 'Unable to locate Tizen CLI executable.'),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
    });

    testUsingContext('Output TPK is missing', () async {
      fileSystem.file('tizen/tizen-manifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(_kTizenManifestContents);

      await expectLater(
        () => TizenBuilder().buildTpk(
          project: project,
          tizenBuildInfo: tizenBuildInfo,
          targetFile: 'main.dart',
        ),
        throwsToolExit(message: 'The output TPK does not exist.'),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      TizenSdk: () => FakeTizenSdk(fileSystem),
      BuildSystem: () => TestBuildSystem.all(BuildResult(success: true)),
    });

    testUsingContext('Indicates that TPK has been built successfully', () async {
      fileSystem.file('tizen/tizen-manifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(_kTizenManifestContents);

      await TizenBuilder().buildTpk(
        project: project,
        tizenBuildInfo: tizenBuildInfo,
        targetFile: 'main.dart',
      );

      expect(
        logger.statusText,
        contains('Built build/tizen/tpk/package_id-1.0.0.tpk (0.0MB)'),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => logger,
      TizenSdk: () => FakeTizenSdk(fileSystem),
      BuildSystem: () => TestBuildSystem.all(
            BuildResult(success: true),
            (Target target, Environment environment) {
              environment.outputDir.childFile('package_id-1.0.0.tpk').createSync(recursive: true);
            },
          ),
    });

    testUsingContext('Performs code size analysis', () async {
      fileSystem.file('tizen/tizen-manifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(_kTizenManifestContents);

      await TizenBuilder().buildTpk(
        project: project,
        tizenBuildInfo: tizenBuildInfo,
        targetFile: 'main.dart',
        sizeAnalyzer: _FakeSizeAnalyzer(fileSystem: fileSystem, logger: logger),
      );

      final File codeSizeFile = fileSystem.file('.flutter-devtools/tpk-code-size-analysis_01.json');
      expect(codeSizeFile, exists);
      expect(
        logger.statusText,
        contains('A summary of your TPK analysis can be found at'),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => logger,
      TizenSdk: () => FakeTizenSdk(fileSystem),
      BuildSystem: () => TestBuildSystem.all(
            BuildResult(success: true),
            (Target target, Environment environment) {
              environment.outputDir.childDirectory('tpkroot').createSync(recursive: true);
              environment.outputDir.childFile('package_id-1.0.0.tpk').createSync(recursive: true);
            },
          ),
      FileSystemUtils: () => FileSystemUtils(fileSystem: fileSystem, platform: platform),
    });

    testUsingContext('Prints stack traces only for fatal non-ToolExit errors', () async {
      fileSystem.file('tizen/tizen-manifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(_kTizenManifestContents);

      await expectLater(
        () => TizenBuilder().buildTpk(
          project: project,
          tizenBuildInfo: tizenBuildInfo,
          targetFile: 'main.dart',
        ),
        throwsToolExit(message: 'The build failed.'),
      );

      expect(logger.errorText, contains('Target a failed: Error: tool exit'));
      expect(logger.errorText, isNot(contains('tool_exit_stack')));
      expect(logger.errorText, contains('Target b failed: Bad state: fatal'));
      expect(logger.errorText, contains('fatal_stack'));
      expect(logger.errorText, contains('Target c failed: Bad state: non-fatal'));
      expect(logger.errorText, isNot(contains('warning_stack')));
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => logger,
      TizenSdk: () => FakeTizenSdk(fileSystem),
      BuildSystem: () => TestBuildSystem.all(
            BuildResult(
              success: false,
              exceptions: <String, ExceptionMeasurement>{
                'a': ExceptionMeasurement(
                  'a',
                  _toolExit('tool exit'),
                  StackTrace.fromString('tool_exit_stack'),
                  fatal: true,
                ),
                'b': ExceptionMeasurement(
                  'b',
                  StateError('fatal'),
                  StackTrace.fromString('fatal_stack'),
                  fatal: true,
                ),
                'c': ExceptionMeasurement(
                  'c',
                  StateError('non-fatal'),
                  StackTrace.fromString('warning_stack'),
                ),
              },
            ),
          ),
    });
  });

  group('TizenBuilder.buildModule', () {
    testUsingContext('Indicates that module has been built successfully', () async {
      fileSystem.file('tizen/tizen-manifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(_kTizenManifestContents);

      await TizenBuilder().buildModule(
        project: project,
        tizenBuildInfo: tizenBuildInfo,
        targetFile: 'main.dart',
      );

      expect(logger.statusText, contains('Built build/tizen/module'));
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => logger,
      TizenSdk: () => FakeTizenSdk(fileSystem),
      BuildSystem: () => TestBuildSystem.all(BuildResult(success: true)),
    });
  });
}

class _FakeSizeAnalyzer extends SizeAnalyzer {
  _FakeSizeAnalyzer({
    required super.fileSystem,
    required super.logger,
  }) : super(analytics: const NoOpAnalytics());

  @override
  Future<Map<String, Object?>> analyzeAotSnapshot({
    required Directory outputDirectory,
    required File aotSnapshot,
    required File precompilerTrace,
    required String type,
    String? excludePath,
  }) async {
    return <String, Object>{};
  }
}

// ToolExit has no public constructor.
ToolExit _toolExit(String message) {
  try {
    throwToolExit(message);
  } on ToolExit catch (error) {
    return error;
  }
}
