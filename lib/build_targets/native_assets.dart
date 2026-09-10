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
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/isolated/native_assets/dart_hook_result.dart';
import 'package:flutter_tools/src/isolated/native_assets/native_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:hooks_runner/hooks_runner.dart' as native;
import 'package:meta/meta.dart';
import 'package:package_config/package_config.dart';

/// Runs the build hooks of all packages with native assets.
///
/// Source: [BuildHooks] in `native_assets.dart`
class TizenBuildHooks extends Target {
  const TizenBuildHooks({
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
    final BuildMode buildMode = _getBuildModeFromEnvironment(environment, name);
    final FlutterNativeAssetsBuildRunner buildRunner =
        _buildRunner ?? _createBuildRunner(environment, buildMode);

    final File resultFile = environment.buildDir.childFile(resultFilename);
    if (!resultFile.parent.existsSync()) {
      resultFile.parent.createSync(recursive: true);
    }

    final List<String> packagesWithNativeAssets = await buildRunner.packagesWithNativeAssets();
    if (packagesWithNativeAssets.isEmpty) {
      resultFile.writeAsStringSync(json.encode(const <String, Object?>{}));
      _writeDepfile(environment, depFilename, Depfile(const <File>[], <File>[resultFile]));
      return;
    }
    _ensureNativeAssetsFeaturesEnabled(packagesWithNativeAssets);

    final Directory buildDir = fileSystem.directory(environment.projectDir.uri
        .resolve('${getBuildDirectory()}/native_assets/${OS.linux.name}/'));
    if (!buildDir.existsSync()) {
      buildDir.createSync(recursive: true);
    }

    final Architecture architecture = _getTizenNativeArchitecture(targetPlatform);
    final linkingEnabled = buildMode != BuildMode.debug;
    final native.BuildResult? buildResult = await buildRunner.build(
      extensions: _extensionsFor(architecture),
      linkingEnabled: linkingEnabled,
    );
    if (buildResult == null) {
      throwToolExit('Building native assets failed. See the logs for more details.');
    }
    resultFile.writeAsStringSync(json.encode(buildResult.toJson()));

    final depfile = Depfile(
      <File>[for (final Uri dependency in buildResult.dependencies) fileSystem.file(dependency)],
      <File>[resultFile],
    );
    _writeDepfile(environment, depFilename, depfile);
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
      ];

  @override
  String get name => 'build_hooks';

  @override
  List<Source> get outputs => const <Source>[Source.pattern('{BUILD_DIR}/$resultFilename')];

  @override
  List<Target> get dependencies => <Target>[];

  /// The serialized build-hook result consumed by [TizenLinkHooks].
  static const resultFilename = 'build_hooks_result.json';
  static const depFilename = 'build_hooks.d';
}

/// Runs the link hooks and combines the build and link results.
///
/// The record-use experiment is not yet supported on Tizen, so no
/// recorded-uses information is passed to the link hooks.
///
/// Source: [LinkHooks] in `native_assets.dart`
class TizenLinkHooks extends Target {
  const TizenLinkHooks({
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
    final BuildMode buildMode = _getBuildModeFromEnvironment(environment, name);

    // Read the result of [TizenBuildHooks].
    final File buildResultFile = environment.buildDir.childFile(TizenBuildHooks.resultFilename);
    if (!buildResultFile.existsSync()) {
      throw StateError("${buildResultFile.path} doesn't exist.");
    }
    final serializedBuildResult =
        json.decode(buildResultFile.readAsStringSync()) as Map<String, Object?>;

    DartHooksResult combinedResult;
    var linkDependencies = const <Uri>[];
    if (serializedBuildResult.isEmpty) {
      // No packages with native assets.
      combinedResult = DartHooksResult.empty();
    } else {
      final buildStart = DateTime.now();
      final buildResult = native.BuildResult.fromJson(serializedBuildResult);
      final Architecture architecture = _getTizenNativeArchitecture(targetPlatform);
      final linkingEnabled = buildMode != BuildMode.debug;

      native.LinkResult? linkResult;
      if (linkingEnabled) {
        if (featureFlags.isRecordUseEnabled) {
          globals.printStatus(
            'The record-use experiment is not yet supported on Tizen. '
            'Native asset tree-shaking is disabled and all assets are bundled.',
          );
        }
        final FlutterNativeAssetsBuildRunner buildRunner =
            _buildRunner ?? _createBuildRunner(environment, buildMode);
        linkResult = await buildRunner.link(
          extensions: _extensionsFor(architecture),
          buildResult: buildResult,
          // Not yet supported on Tizen: no recorded-uses info is passed to hooks.
          recordedUsesFile: null,
        );
        if (linkResult == null) {
          throwToolExit('Linking native assets failed. See the logs for more details.');
        }
        linkDependencies = linkResult.dependencies;
      }
      combinedResult = _combineResults(
        architecture: architecture,
        buildResult: buildResult,
        linkResult: linkResult,
        buildStart: buildStart,
      );
    }

    final File resultFile = environment.buildDir.childFile(resultFilename);
    if (!resultFile.parent.existsSync()) {
      resultFile.parent.createSync(recursive: true);
    }
    resultFile.writeAsStringSync(json.encode(combinedResult.toJson()));

    final depfile = Depfile(
      <File>[for (final Uri dependency in linkDependencies) fileSystem.file(dependency)],
      <File>[resultFile],
    );
    _writeDepfile(environment, depFilename, depfile);
  }

  @override
  List<String> get depfiles => const <String>[depFilename];

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{BUILD_DIR}/${TizenBuildHooks.resultFilename}'),
      ];

  @override
  String get name => 'link_hooks';

  @override
  List<Source> get outputs => const <Source>[Source.pattern('{BUILD_DIR}/$resultFilename')];

  @override
  List<Target> get dependencies => const <Target>[TizenBuildHooks()];

  /// Dependent build [Target]s can use this to consume the result of the
  /// [TizenLinkHooks] target.
  static Future<DartHooksResult> loadHookResult(Environment environment) async {
    final File resultFile = environment.buildDir.childFile(resultFilename);
    if (!resultFile.existsSync()) {
      return DartHooksResult.empty();
    }
    return DartHooksResult.fromJson(
      json.decode(resultFile.readAsStringSync()) as Map<String, Object?>,
    );
  }

  /// The combined [DartHooksResult] serialized.
  static const resultFilename = 'link_hooks_result.json';
  static const depFilename = 'link_hooks.d';
}

/// Source: [InstallCodeAssets] in `native_assets.dart`
class TizenInstallCodeAssets extends Target {
  const TizenInstallCodeAssets();

  @override
  Future<void> build(Environment environment) async {
    final Uri projectUri = environment.projectDir.uri;
    final FileSystem fileSystem = environment.fileSystem;
    final TargetPlatform targetPlatform = _getTargetPlatformFromEnvironment(environment, name);

    // We fetch the combined result from the [TizenLinkHooks].
    final DartHooksResult dartHookResult = await TizenLinkHooks.loadHookResult(environment);

    // And install/copy the code assets to the right place and create a
    // native_asset.yaml that can be used by the final AOT compilation.
    final Uri nativeAssetsFileUri = environment.buildDir.childFile(nativeAssetsFilename).uri;

    // Tizen builds native assets as Linux shared objects, so the install
    // location keeps the Linux directory layout. Install into the build
    // directory; the package targets copy the assets into the TPK lib
    // directory from there.
    final Uri targetUri =
        environment.buildDir.childDirectory('native_assets').uri.resolve('${OS.linux.name}/');

    await installCodeAssets(
      dartHookResult: dartHookResult,
      environmentDefines: environment.defines,
      targetPlatform: targetPlatform,
      projectUri: projectUri,
      fileSystem: fileSystem,
      nativeAssetsFileUri: nativeAssetsFileUri,
      targetUri: targetUri,
    );
    assert(fileSystem.file(nativeAssetsFileUri).existsSync());

    // installCodeAssets uses the Android directory layout for the Android
    // alias target platforms (jniLibs/lib/<abi>/...). Tizen loads native
    // assets from the flat TPK lib directory, so flatten the installed files.
    final Directory installDir = fileSystem.directory(targetUri);
    for (final FileSystemEntity entity in installDir.listSync(recursive: true)) {
      if (entity is File && entity.parent.path != installDir.path) {
        entity.renameSync(installDir.childFile(entity.basename).path);
      }
    }
    for (final FileSystemEntity entity in installDir.listSync()) {
      if (entity is Directory) {
        entity.deleteSync(recursive: true);
      }
    }

    final depfile = Depfile(
      <File>[for (final Uri file in dartHookResult.filesToBeBundled) fileSystem.file(file)],
      <File>[fileSystem.file(nativeAssetsFileUri)],
    );
    final File outputDepfile = environment.buildDir.childFile(depFilename);
    environment.depFileService.writeToFile(depfile, outputDepfile);
    if (!outputDepfile.existsSync()) {
      throwToolExit("${outputDepfile.path} doesn't exist.");
    }
  }

  @override
  List<String> get depfiles => <String>[depFilename];

  @override
  List<Target> get dependencies => const <Target>[TizenLinkHooks()];

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern(
          '{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/native_assets.dart',
        ),
        Source.pattern('{BUILD_DIR}/${TizenLinkHooks.resultFilename}'),
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
  return TargetPlatform.fromName(targetPlatformEnvironment);
}

BuildMode _getBuildModeFromEnvironment(Environment environment, String name) {
  final String? buildModeEnvironment = environment.defines[kBuildMode];
  if (buildModeEnvironment == null) {
    throw MissingDefineException(kBuildMode, name);
  }
  return BuildMode.fromCliName(buildModeEnvironment);
}

FlutterNativeAssetsBuildRunner _createBuildRunner(Environment environment, BuildMode buildMode) {
  final FileSystem fileSystem = environment.fileSystem;
  final File packageConfigFile = fileSystem.file(environment.packageConfigPath);
  final PackageConfig packageConfig = PackageConfig.parseBytes(
    packageConfigFile.readAsBytesSync(),
    packageConfigFile.uri,
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
  return FlutterNativeAssetsBuildRunnerImpl(
    environment.packageConfigPath,
    packageConfig,
    fileSystem,
    environment.logger,
    runPackageName,
    includeDevDependencies: !buildMode.isRelease,
    pubspecPath,
  );
}

void _ensureNativeAssetsFeaturesEnabled(List<String> packagesWithNativeAssets) {
  if (!featureFlags.isNativeAssetsEnabled && !featureFlags.isDartDataAssetsEnabled) {
    throwToolExit(
      'Package(s) ${packagesWithNativeAssets.join(' ')} require the dart assets feature to be enabled.\n'
      '  Enable code assets using `flutter-tizen config --enable-native-assets`.\n'
      '  Enable data assets using `flutter-tizen config --enable-dart-data-assets`.',
    );
  }
}

List<ProtocolExtension> _extensionsFor(Architecture architecture) {
  // Do not call setCCompilerConfig here. Flutter's Linux compiler discovery
  // would return a host compiler, not a Tizen rootstrap-aware compiler.
  return <ProtocolExtension>[
    if (featureFlags.isNativeAssetsEnabled)
      CodeAssetExtension(
        targetArchitecture: architecture,
        linkModePreference: LinkModePreference.dynamic,
        targetOS: OS.linux,
      ),
    if (featureFlags.isDartDataAssetsEnabled) DataAssetsExtension(),
  ];
}

DartHooksResult _combineResults({
  required Architecture architecture,
  required native.BuildResult buildResult,
  required native.LinkResult? linkResult,
  required DateTime buildStart,
}) {
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

void rewriteNativeAssetsManifest(File manifestFile, String packageId) {
  if (!manifestFile.existsSync()) {
    return;
  }
  final deviceLibDir = '/opt/usr/globalapps/$packageId/lib';
  final manifestJson = json.decode(manifestFile.readAsStringSync()) as Map<String, Object?>;
  final Map<String, Object?> nativeAssets =
      manifestJson['native-assets'] as Map<String, Object?>? ?? <String, Object?>{};
  for (final Object? assets in nativeAssets.values) {
    if (assets is! Map<String, Object?>) {
      continue;
    }
    for (final MapEntry<String, Object?> asset in assets.entries) {
      final Object? path = asset.value;
      if (path is List<Object?> &&
          path.length == 2 &&
          (path[0] == 'absolute' || path[0] == 'relative')) {
        final String fileName = manifestFile.fileSystem.path.basename(path[1]! as String);
        assets[asset.key] = <String>['absolute', '$deviceLibDir/$fileName'];
      }
    }
  }
  manifestFile.writeAsStringSync(json.encode(manifestJson));
}

void _writeDepfile(Environment environment, String filename, Depfile depfile) {
  final File outputDepfile = environment.buildDir.childFile(filename);
  if (!outputDepfile.parent.existsSync()) {
    outputDepfile.parent.createSync(recursive: true);
  }
  environment.depFileService.writeToFile(depfile, outputDepfile);
  if (!outputDepfile.existsSync()) {
    throw StateError("${outputDepfile.path} doesn't exist.");
  }
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
