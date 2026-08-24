// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:code_assets/code_assets.dart';
import 'package:data_assets/data_assets.dart';
import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
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

  Environment createEnvironment(Directory projectDir, String buildMode, String targetPlatform) {
    return Environment.test(
      projectDir,
      defines: <String, String>{kBuildMode: buildMode, kTargetPlatform: targetPlatform},
      fileSystem: fileSystem,
      logger: logger,
      artifacts: Artifacts.test(),
      processManager: processManager,
    );
  }

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
      final Environment environment = createEnvironment(projectDir, 'debug', entry.key);
      final runner = _RecordingRunner();

      await TizenBuildHooks(buildRunner: runner).build(environment);

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
    final Environment environment = createEnvironment(projectDir, 'debug', 'android-arm64');
    final runner = _RecordingRunner(
      buildResult: _BuildResult(<EncodedAsset>[
        DataAsset(package: 'native_package', name: 'data.txt', file: dataFile.uri).encode(),
      ]),
    );

    await TizenBuildHooks(buildRunner: runner).build(environment);
    await TizenLinkHooks(buildRunner: runner).build(environment);

    expect(runner.extensions!.whereType<CodeAssetExtension>(), hasLength(1));
    expect(runner.extensions!.whereType<DataAssetsExtension>(), hasLength(1));
    // Link hooks must not run for debug builds.
    expect(runner.linkCalls, 0);
    final DartHooksResult result = await TizenLinkHooks.loadHookResult(environment);
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

  testUsingContext('Link hooks run for release builds without recorded uses', () async {
    final Directory projectDir = fileSystem.currentDirectory;
    writePackageConfigFiles(directory: projectDir, mainLibName: 'my_app');
    final File dataFile = projectDir.childFile('data.txt')..writeAsStringSync('data');
    final File linkedFile = projectDir.childFile('linked.txt')..writeAsStringSync('linked');
    final Environment environment = createEnvironment(projectDir, 'release', 'android-arm64');
    final runner = _RecordingRunner(
      buildResult: _BuildResult(<EncodedAsset>[
        DataAsset(package: 'native_package', name: 'data.txt', file: dataFile.uri).encode(),
      ]),
      linkResult: _LinkResult(<EncodedAsset>[
        DataAsset(package: 'native_package', name: 'linked.txt', file: linkedFile.uri).encode(),
      ]),
    );

    await TizenBuildHooks(buildRunner: runner).build(environment);
    await TizenLinkHooks(buildRunner: runner).build(environment);

    expect(runner.linkCalls, 1);
    expect(runner.recordedUsesFileArg, isNull);
    final DartHooksResult result = await TizenLinkHooks.loadHookResult(environment);
    expect(
      result.dataAssets.map((DataAsset asset) => asset.id),
      unorderedEquals(<String>[
        'package:native_package/data.txt',
        'package:native_package/linked.txt',
      ]),
    );
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    FeatureFlags: () => TestFeatureFlags(
          isNativeAssetsEnabled: true,
          isDartDataAssetsEnabled: true,
        ),
    ProcessManager: () => processManager,
  });

  testUsingContext('Link hooks emit an empty result without native asset packages', () async {
    final Directory projectDir = fileSystem.currentDirectory;
    writePackageConfigFiles(directory: projectDir, mainLibName: 'my_app');
    final Environment environment = createEnvironment(projectDir, 'release', 'android-arm64');
    final runner = _RecordingRunner(packages: const <String>[]);

    await TizenBuildHooks(buildRunner: runner).build(environment);
    await TizenLinkHooks(buildRunner: runner).build(environment);

    expect(runner.buildCalls, 0);
    expect(runner.linkCalls, 0);
    final DartHooksResult result = await TizenLinkHooks.loadHookResult(environment);
    expect(result.codeAssets, isEmpty);
    expect(result.dataAssets, isEmpty);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    FeatureFlags: () => TestFeatureFlags(isNativeAssetsEnabled: true),
    ProcessManager: () => processManager,
  });

  testUsingContext('Install flattens code assets out of the Android layout', () async {
    final Directory projectDir = fileSystem.currentDirectory;
    final File soFile = projectDir.childFile('libmy_asset.so')..writeAsStringSync('so');
    final Environment environment = createEnvironment(projectDir, 'debug', 'android-x64');
    final result = DartHooksResult(
      buildStart: DateTime.now(),
      buildEnd: DateTime.now(),
      codeAssets: <FlutterCodeAsset>[
        FlutterCodeAsset(
          codeAsset: CodeAsset(
            package: 'my_pkg',
            name: 'my_asset.dart',
            linkMode: DynamicLoadingBundled(),
            file: soFile.uri,
          ),
          target: native.Target.fromArchitectureAndOS(Architecture.x64, OS.linux),
        ),
      ],
      dataAssets: const <DataAsset>[],
      dependencies: const <Uri>[],
    );
    environment.buildDir.childFile(TizenLinkHooks.resultFilename)
      ..createSync(recursive: true)
      ..writeAsStringSync(json.encode(result.toJson()));

    await const TizenInstallCodeAssets().build(environment);

    // Flattened out of the Android jniLibs directory layout.
    expect(environment.buildDir.childFile('native_assets/linux/libmy_asset.so'), exists);
    final manifest = json.decode(
      environment.buildDir.childFile('native_assets.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final assets =
        (manifest['native-assets']! as Map<String, Object?>)['linux_x64']! as Map<String, Object?>;
    // Path rewriting happens later during package assembly, where the final
    // application package ID is known.
    expect(assets['package:my_pkg/my_asset.dart'], <String>['absolute', 'libmy_asset.so']);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
  });
}

class _RecordingRunner implements FlutterNativeAssetsBuildRunner {
  _RecordingRunner({
    native.BuildResult buildResult = const _BuildResult(),
    native.LinkResult? linkResult,
    List<String> packages = const <String>['native_package'],
  })  : _buildResult = buildResult,
        _linkResult = linkResult,
        _packages = packages;

  final native.BuildResult _buildResult;
  final native.LinkResult? _linkResult;
  final List<String> _packages;
  List<ProtocolExtension>? extensions;
  int buildCalls = 0;
  int linkCalls = 0;
  File? recordedUsesFileArg;
  int setCCompilerConfigCalls = 0;

  @override
  Future<List<String>> packagesWithNativeAssets() async => _packages;

  @override
  Future<native.BuildResult?> build({
    required List<ProtocolExtension> extensions,
    required bool linkingEnabled,
  }) async {
    buildCalls++;
    this.extensions = extensions;
    return _buildResult;
  }

  @override
  Future<native.LinkResult?> link({
    required List<ProtocolExtension> extensions,
    required native.BuildResult buildResult,
    required File? recordedUsesFile,
  }) async {
    if (_linkResult == null) {
      throw StateError('Link hooks should not run for this test.');
    }
    linkCalls++;
    recordedUsesFileArg = recordedUsesFile;
    return _linkResult;
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

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'encodedAssets': <Object?>[
          for (final EncodedAsset asset in encodedAssets) asset.toJson(),
        ],
        'encodedAssetsForLinking': const <String, Object?>{},
        'dependencies': const <String>[],
      };
}

class _LinkResult implements native.LinkResult {
  const _LinkResult([this.encodedAssets = const <EncodedAsset>[]]);

  @override
  final List<EncodedAsset> encodedAssets;

  @override
  List<Uri> get dependencies => const <Uri>[];
}
