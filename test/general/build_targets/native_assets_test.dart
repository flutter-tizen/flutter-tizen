// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:code_assets/code_assets.dart';
import 'package:data_assets/data_assets.dart';
import 'package:file/memory.dart';
import 'package:flutter_tizen/build_targets/native_assets.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/isolated/native_assets/dart_hook_result.dart';
import 'package:flutter_tools/src/isolated/native_assets/native_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:hooks_runner/hooks_runner.dart' as native;

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fakes.dart';
import '../../src/package_config.dart';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late Logger logger;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.any();
    logger = BufferLogger.test();
  });

  const cases = <String, Architecture>{
    'android-arm': Architecture.arm,
    'android-arm64': Architecture.arm64,
    'android-x64': Architecture.x64,
    'flutter-tester': Architecture.ia32,
  };

  for (final MapEntry<String, Architecture> entry in cases.entries) {
    testUsingContext('Tizen hooks use Linux OS for ${entry.key}', () async {
      final Directory projectDir = fileSystem.currentDirectory;
      writePackageConfigFiles(directory: projectDir, mainLibName: 'my_app');
      final environment = Environment.test(
        projectDir,
        defines: <String, String>{
          kBuildMode: 'debug',
          kTargetPlatform: entry.key,
        },
        fileSystem: fileSystem,
        logger: logger,
        artifacts: Artifacts.test(),
        processManager: processManager,
      );
      final runner = _RecordingRunner();

      await TizenDartBuild(buildRunner: runner).build(environment);

      final CodeAssetExtension codeExtension =
          runner.extensions!.whereType<CodeAssetExtension>().single;
      expect(codeExtension.targetOS, OS.linux);
      expect(codeExtension.targetArchitecture, entry.value);
      expect(codeExtension.android, isNull);
      expect(runner.setCCompilerConfigCalls, 0);
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      FeatureFlags: () => TestFeatureFlags(isNativeAssetsEnabled: true),
      ProcessManager: () => processManager,
    });
  }

  testUsingContext('Tizen hooks preserve data assets when enabled', () async {
    final Directory projectDir = fileSystem.currentDirectory;
    writePackageConfigFiles(directory: projectDir, mainLibName: 'my_app');
    final File dataFile = projectDir.childFile('data.txt')..writeAsStringSync('data');
    final environment = Environment.test(
      projectDir,
      defines: <String, String>{
        kBuildMode: 'debug',
        kTargetPlatform: 'android-arm64',
      },
      fileSystem: fileSystem,
      logger: logger,
      artifacts: Artifacts.test(),
      processManager: processManager,
    );
    final runner = _RecordingRunner(
      buildResult: _BuildResult(<EncodedAsset>[
        DataAsset(package: 'native_package', name: 'data.txt', file: dataFile.uri).encode(),
      ]),
    );

    await TizenDartBuild(buildRunner: runner).build(environment);

    expect(runner.extensions!.whereType<CodeAssetExtension>(), hasLength(1));
    expect(runner.extensions!.whereType<DataAssetsExtension>(), hasLength(1));
    final DartHooksResult result = await TizenDartBuild.loadHookResult(environment);
    expect(result.dataAssets, hasLength(1));
    expect(result.dataAssets.single.id, 'package:native_package/data.txt');
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    FeatureFlags: () => TestFeatureFlags(
          isNativeAssetsEnabled: true,
          isDartDataAssetsEnabled: true,
        ),
    ProcessManager: () => processManager,
  });
}

class _RecordingRunner implements FlutterNativeAssetsBuildRunner {
  _RecordingRunner({native.BuildResult buildResult = const _BuildResult()})
      : _buildResult = buildResult;

  final native.BuildResult _buildResult;
  List<ProtocolExtension>? extensions;
  int setCCompilerConfigCalls = 0;

  @override
  Future<List<String>> packagesWithNativeAssets() async => <String>['native_package'];

  @override
  Future<native.BuildResult?> build({
    required List<ProtocolExtension> extensions,
    required bool linkingEnabled,
  }) async {
    this.extensions = extensions;
    return _buildResult;
  }

  @override
  Future<native.LinkResult?> link({
    required List<ProtocolExtension> extensions,
    required native.BuildResult buildResult,
  }) async {
    throw StateError('Link hooks should not run for debug builds.');
  }

  @override
  Future<void> setCCompilerConfig(Object target) async {
    setCCompilerConfigCalls++;
  }
}

class _BuildResult implements native.BuildResult {
  const _BuildResult([this.encodedAssets = const <EncodedAsset>[]]);

  @override
  final List<EncodedAsset> encodedAssets;

  @override
  Map<String, List<EncodedAsset>> get encodedAssetsForLinking =>
      const <String, List<EncodedAsset>>{};

  @override
  List<Uri> get dependencies => const <Uri>[];
}
