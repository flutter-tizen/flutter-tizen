// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:code_assets/code_assets.dart';
import 'package:data_assets/data_assets.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/exceptions.dart';
import 'package:flutter_tools/src/build_system/targets/native_assets.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/dart/package_map.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/isolated/native_assets/dart_hook_result.dart';
import 'package:flutter_tools/src/isolated/native_assets/native_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:hooks_runner/hooks_runner.dart' as native;
import 'package:meta/meta.dart';
import 'package:package_config/package_config_types.dart';

/// Source: [DartBuild] in `native_assets.dart`
class TizenDartBuild extends Target {
  const TizenDartBuild({
    @visibleForTesting FlutterNativeAssetsBuildRunner? buildRunner,
    this.specifiedTargetPlatform,
  }) : _buildRunner = buildRunner;

  final FlutterNativeAssetsBuildRunner? _buildRunner;

  /// The target OS and architecture that we are building for.
  final TargetPlatform? specifiedTargetPlatform;

  @override
  Future<void> build(Environment environment) async {
    final FileSystem fileSystem = environment.fileSystem;
    final TargetPlatform targetPlatform =
        specifiedTargetPlatform ?? _getTargetPlatformFromEnvironment(environment, name);

    final File packageConfigFile = fileSystem.file(environment.packageConfigPath);
    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
      packageConfigFile,
      logger: environment.logger,
    );
    final Uri projectUri = environment.projectDir.uri;
    final String? runPackageName =
        packageConfig.packages.where((Package p) => p.root == projectUri).firstOrNull?.name;
    if (runPackageName == null) {
      throw StateError(
        'Could not determine run package name. '
        'Project path "${projectUri.toFilePath()}" did not occur as package '
        'root in package config "${environment.packageConfigPath}". '
        'Please report a reproduction on '
        'https://github.com/flutter/flutter/issues/169475.',
      );
    }
    final String pubspecPath = packageConfigFile.uri.resolve('../pubspec.yaml').toFilePath();
    final String? buildModeEnvironment = environment.defines[kBuildMode];
    if (buildModeEnvironment == null) {
      throw MissingDefineException(kBuildMode, name);
    }
    final buildMode = BuildMode.fromCliName(buildModeEnvironment);
    final bool includeDevDependencies = !buildMode.isRelease;
    final FlutterNativeAssetsBuildRunner buildRunner = _buildRunner ??
        FlutterNativeAssetsBuildRunnerImpl(
          environment.packageConfigPath,
          packageConfig,
          fileSystem,
          environment.logger,
          runPackageName,
          includeDevDependencies: includeDevDependencies,
          pubspecPath,
        );
    final DartHooksResult result = await _runTizenSpecificHooks(
      buildRunner: buildRunner,
      targetPlatform: targetPlatform,
      projectUri: projectUri,
      fileSystem: fileSystem,
      buildMode: buildMode,
    );
    final File dartHookResultJsonFile = environment.buildDir.childFile(dartHookResultFilename);
    if (!dartHookResultJsonFile.parent.existsSync()) {
      dartHookResultJsonFile.parent.createSync(recursive: true);
    }
    dartHookResultJsonFile.writeAsStringSync(json.encode(result.toJson()));

    final depfile = Depfile(
      <File>[for (final Uri dependency in result.dependencies) fileSystem.file(dependency)],
      <File>[fileSystem.file(dartHookResultJsonFile)],
    );
    final File outputDepfile = environment.buildDir.childFile(depFilename);
    if (!outputDepfile.parent.existsSync()) {
      outputDepfile.parent.createSync(recursive: true);
    }
    environment.depFileService.writeToFile(depfile, outputDepfile);
    if (!await outputDepfile.exists()) {
      throw StateError("${outputDepfile.path} doesn't exist.");
    }
  }

  @override
  List<String> get depfiles => const <String>[depFilename];

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern(
          '{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/native_assets.dart',
        ),
        // If different packages are resolved, different native assets might need to be built.
        Source.pattern('{WORKSPACE_DIR}/.dart_tool/package_config.json'),
        // TODO(mosuem): Should consume resources.json. https://github.com/flutter/flutter/issues/146263
      ];

  @override
  String get name => 'dart_build';

  @override
  List<Source> get outputs => const <Source>[Source.pattern('{BUILD_DIR}/$dartHookResultFilename')];

  /// Dependent build [Target]s can use this to consume the result of the
  /// [TizenDartBuild] target.
  static Future<DartHooksResult> loadHookResult(Environment environment) async {
    final File dartHookResultJsonFile = environment.buildDir.childFile(
      TizenDartBuild.dartHookResultFilename,
    );
    if (!dartHookResultJsonFile.existsSync()) {
      return DartHooksResult.empty();
    }
    return DartHooksResult.fromJson(
      json.decode(dartHookResultJsonFile.readAsStringSync()) as Map<String, Object?>,
    );
  }

  @override
  List<Target> get dependencies => <Target>[];

  static const dartHookResultFilename = 'dart_build_result.json';
  static const depFilename = 'dart_build.d';
}

/// Source: [DartBuildForNative] in `native_assets.dart`
class TizenDartBuildForNative extends TizenDartBuild {
  const TizenDartBuildForNative({@visibleForTesting super.buildRunner});

  // TODO(dcharkes): Add `KernelSnapshot()` for AOT builds only when adding tree-shaking information. https://github.com/dart-lang/native/issues/153
  @override
  List<Target> get dependencies => const <Target>[];
}

/// Source: [InstallCodeAssets] in `native_assets.dart`
class TizenInstallCodeAssets extends Target {
  const TizenInstallCodeAssets();

  @override
  Future<void> build(Environment environment) async {
    final Uri projectUri = environment.projectDir.uri;
    final FileSystem fileSystem = environment.fileSystem;
    final TargetPlatform targetPlatform = _getTargetPlatformFromEnvironment(environment, name);

    // We fetch the result from the [DartBuild].
    final DartHooksResult dartHookResult = await TizenDartBuild.loadHookResult(environment);

    // And install/copy the code assets to the right place and create a
    // native_asset.yaml that can be used by the final AOT compilation.
    final Uri nativeAssetsFileUri = environment.buildDir.childFile(nativeAssetsFilename).uri;
    await installCodeAssets(
      dartHookResult: dartHookResult,
      environmentDefines: environment.defines,
      targetPlatform: targetPlatform,
      projectUri: projectUri,
      fileSystem: fileSystem,
      nativeAssetsFileUri: nativeAssetsFileUri,
    );
    assert(await fileSystem.file(nativeAssetsFileUri).exists());

    final depfile = Depfile(
      <File>[for (final Uri file in dartHookResult.filesToBeBundled) fileSystem.file(file)],
      <File>[fileSystem.file(nativeAssetsFileUri)],
    );
    final File outputDepfile = environment.buildDir.childFile(depFilename);
    environment.depFileService.writeToFile(depfile, outputDepfile);
    if (!await outputDepfile.exists()) {
      throwToolExit("${outputDepfile.path} doesn't exist.");
    }
  }

  @override
  List<String> get depfiles => <String>[depFilename];

  @override
  List<Target> get dependencies => const <Target>[TizenDartBuildForNative()];

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern(
          '{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/native_assets.dart',
        ),
        // If different packages are resolved, different native assets might need to be built.
        Source.pattern('{WORKSPACE_DIR}/.dart_tool/package_config.json'),
      ];

  @override
  String get name => 'install_code_assets';

  @override
  List<Source> get outputs => const <Source>[Source.pattern('{BUILD_DIR}/$nativeAssetsFilename')];

  static const nativeAssetsFilename = 'native_assets.json';
  static const depFilename = 'install_code_assets.d';
}

TargetPlatform _getTargetPlatformFromEnvironment(Environment environment, String name) {
  final String? targetPlatformEnvironment = environment.defines[kTargetPlatform];
  if (targetPlatformEnvironment == null) {
    throw MissingDefineException(kTargetPlatform, name);
  }
  return getTargetPlatformForName(targetPlatformEnvironment);
}

Future<DartHooksResult> _runTizenSpecificHooks({
  required FlutterNativeAssetsBuildRunner buildRunner,
  required TargetPlatform targetPlatform,
  required Uri projectUri,
  required FileSystem fileSystem,
  required BuildMode buildMode,
}) async {
  final Directory buildDir = fileSystem.directory(nativeAssetsBuildUri(projectUri, OS.linux.name));
  if (!buildDir.existsSync()) {
    buildDir.createSync(recursive: true);
  }

  final List<String> packagesWithNativeAssets = await buildRunner.packagesWithNativeAssets();
  if (packagesWithNativeAssets.isEmpty) {
    return DartHooksResult.empty();
  }
  if (!featureFlags.isNativeAssetsEnabled && !featureFlags.isDartDataAssetsEnabled) {
    throwToolExit(
      'Package(s) ${packagesWithNativeAssets.join(' ')} require the dart assets feature to be enabled.\n'
      '  Enable code assets using `flutter-tizen config --enable-native-assets`.\n'
      '  Enable data assets using `flutter-tizen config --enable-dart-data-assets`.',
    );
  }

  final Architecture architecture = _getTizenNativeArchitecture(targetPlatform);
  // Do not call setCCompilerConfig here. Flutter's Linux compiler discovery
  // would return a host compiler, not a Tizen rootstrap-aware compiler.
  final extensions = <ProtocolExtension>[
    if (featureFlags.isNativeAssetsEnabled)
      CodeAssetExtension(
        targetArchitecture: architecture,
        linkModePreference: LinkModePreference.dynamic,
        targetOS: OS.linux,
      ),
    if (featureFlags.isDartDataAssetsEnabled) DataAssetsExtension(),
  ];
  final linkingEnabled = buildMode != BuildMode.debug;
  final buildStart = DateTime.now();

  final native.BuildResult? buildResult =
      await buildRunner.build(extensions: extensions, linkingEnabled: linkingEnabled);
  if (buildResult == null) {
    throwToolExit('Building native assets failed. See the logs for more details.');
  }

  native.LinkResult? linkResult;
  if (linkingEnabled) {
    linkResult = await buildRunner.link(extensions: extensions, buildResult: buildResult);
    if (linkResult == null) {
      throwToolExit('Linking native assets failed. See the logs for more details.');
    }
  }

  final target = native.Target.fromArchitectureAndOS(architecture, OS.linux);
  final encodedAssets = <EncodedAsset>[
    ...buildResult.encodedAssets,
    if (linkResult != null) ...linkResult.encodedAssets,
  ];
  final codeAssets = <FlutterCodeAsset>[
    for (final EncodedAsset asset in encodedAssets)
      if (asset.isCodeAsset) FlutterCodeAsset(codeAsset: asset.asCodeAsset, target: target),
  ];
  final dataAssets = <DataAsset>[
    for (final EncodedAsset asset in encodedAssets)
      if (asset.isDataAsset) DataAsset.fromEncoded(asset),
  ];
  if (dataAssets.map((DataAsset asset) => asset.id).toSet().length != dataAssets.length) {
    throwToolExit(
      'Found duplicates in the data assets: '
      '${dataAssets.map((DataAsset asset) => asset.id).toList()} '
      'while compiling for linux_${architecture.name}.',
    );
  }
  if (codeAssets.toSet().length != codeAssets.length) {
    throwToolExit(
      'Found duplicates in the code assets: '
      '${codeAssets.map((FlutterCodeAsset asset) => asset.codeAsset.id).toList()} '
      'while compiling for linux_${architecture.name}.',
    );
  }

  return DartHooksResult(
    buildStart: buildStart,
    buildEnd: DateTime.now(),
    codeAssets: codeAssets,
    dataAssets: dataAssets,
    dependencies: <Uri>{
      ...buildResult.dependencies,
      if (linkResult != null) ...linkResult.dependencies,
    }.toList(),
  );
}

/// Tizen reuses Flutter's Android/tester target platforms as architecture
/// aliases. Dart hooks must see the actual Tizen runtime OS, which is Linux.
Architecture _getTizenNativeArchitecture(TargetPlatform targetPlatform) {
  return switch (targetPlatform) {
    TargetPlatform.android_arm => Architecture.arm,
    TargetPlatform.android_arm64 => Architecture.arm64,
    TargetPlatform.android_x64 => Architecture.x64,
    TargetPlatform.tester => Architecture.ia32,
    _ => throwToolExit('Native assets are not supported for $targetPlatform on Tizen.'),
  };
}
