// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:code_assets/code_assets.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/exceptions.dart';
import 'package:flutter_tools/src/build_system/targets/native_assets.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/dart/package_map.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/isolated/native_assets/dart_hook_result.dart';
import 'package:flutter_tools/src/isolated/native_assets/linux/native_assets.dart';
import 'package:flutter_tools/src/isolated/native_assets/native_assets.dart';
import 'package:flutter_tools/src/isolated/native_assets/targets.dart';
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
    final DartHooksResult result;

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
        TizenFlutterNativeAssetsBuildRunnerImpl(
          environment.packageConfigPath,
          packageConfig,
          fileSystem,
          environment.logger,
          runPackageName,
          includeDevDependencies: includeDevDependencies,
          pubspecPath,
        );
    result = await runFlutterSpecificHooks(
      environmentDefines: environment.defines,
      buildRunner: buildRunner,
      targetPlatform: targetPlatform,
      projectUri: projectUri,
      fileSystem: fileSystem,
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

class TizenFlutterNativeAssetsBuildRunnerImpl extends FlutterNativeAssetsBuildRunnerImpl {
  TizenFlutterNativeAssetsBuildRunnerImpl(
    super.packageConfigPath,
    super.packageConfig,
    super.fileSystem,
    super.logger,
    super.runPackageName,
    super.pubspecPath, {
    required super.includeDevDependencies,
  });

  @override
  Future<void> setCCompilerConfig(CodeAssetTarget target) async {
    if (target is AndroidAssetTarget) {
      target.cCompilerConfigSync = await _hostCCompilerConfigLinux(
        fileSystem: fileSystem,
        throwIfNotFound: true,
      );
    } else {
      await target.setCCompilerConfig();
    }
  }
}

Future<CCompilerConfig?> _hostCCompilerConfigLinux({
  required FileSystem fileSystem,
  required bool throwIfNotFound,
}) async {
  final CCompilerConfig? upstreamConfig = await cCompilerConfigLinux(
    throwIfNotFound: false,
  );
  if (upstreamConfig != null) {
    return upstreamConfig;
  }

  const clangPpBinary = 'clang++';
  const kClangBinaryOptions = <String>['clang'];
  const kArBinaryOptions = <String>['llvm-ar', 'ar'];
  const kLdBinaryOptions = <String>['ld.lld', 'ld'];

  final File? clangPpFile = globals.os.which(clangPpBinary);
  if (clangPpFile == null) {
    if (throwIfNotFound) {
      throwToolExit(
        'Failed to find $clangPpBinary on PATH.\n'
        "Run 'sudo apt install clang'.",
      );
    }
    return null;
  }

  final File resolvedClangPpFile = fileSystem.file(await clangPpFile.resolveSymbolicLinks());
  final Directory clangDir = resolvedClangPpFile.parent;

  Uri? findExecutable({required List<String> possibleExecutableNames, required Directory path}) {
    final Uri? found = _findExecutableIfExists(
      possibleExecutableNames: possibleExecutableNames,
      path: path,
    );

    if (found == null && throwIfNotFound) {
      final String packageSuggestion = switch (possibleExecutableNames) {
        kClangBinaryOptions => "Run 'sudo apt install clang'.",
        kArBinaryOptions => "Run 'sudo apt install llvm'.",
        _ => '',
      };
      throwToolExit(
        'Failed to find any of $possibleExecutableNames in $path.'
        '${packageSuggestion.isEmpty ? '' : '\n$packageSuggestion'}',
      );
    }

    return found;
  }

  final Uri? compiler = findExecutable(
    path: clangDir,
    possibleExecutableNames: kClangBinaryOptions,
  );
  final Uri? archiver = findExecutable(
    path: clangDir,
    possibleExecutableNames: kArBinaryOptions,
  );

  Uri? linker = _findExecutableIfExists(
    possibleExecutableNames: kLdBinaryOptions,
    path: clangDir,
  );
  linker ??= await _findExecutableOnPath(
    fileSystem: fileSystem,
    possibleExecutableNames: kLdBinaryOptions,
  );

  if (linker == null && throwIfNotFound) {
    throwToolExit(
      'Failed to find any of $kLdBinaryOptions in LocalDirectory: '
      "'${clangDir.path}' or on PATH.\n"
      "Run 'sudo apt install lld' or 'sudo apt install binutils' to install a linker.",
    );
  }

  if (compiler == null || archiver == null || linker == null) {
    assert(!throwIfNotFound);
    return null;
  }

  return CCompilerConfig(
    compiler: compiler,
    archiver: archiver,
    linker: linker,
  );
}

Future<Uri?> _findExecutableOnPath({
  required FileSystem fileSystem,
  required List<String> possibleExecutableNames,
}) async {
  for (final executableName in possibleExecutableNames) {
    final File? executable = globals.os.which(executableName);
    if (executable == null) {
      continue;
    }

    final File resolvedExecutable = fileSystem.file(await executable.resolveSymbolicLinks());
    return resolvedExecutable.uri;
  }
  return null;
}

Uri? _findExecutableIfExists({
  required List<String> possibleExecutableNames,
  required Directory path,
}) {
  return possibleExecutableNames
      .map((execName) => path.childFile(execName))
      .where((file) => file.existsSync())
      .map((file) => file.uri)
      .firstOrNull;
}
