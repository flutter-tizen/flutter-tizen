// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/targets/assets.dart';
import 'package:flutter_tools/src/build_system/targets/icon_tree_shaker.dart';
import 'package:flutter_tools/src/build_system/exceptions.dart';
import 'package:flutter_tools/src/build_system/source.dart';
import 'package:flutter_tools/src/build_system/targets/android.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

import 'tizen_artifacts.dart';
import 'tizen_builder.dart';
import 'tizen_plugins.dart';
import 'tizen_project.dart';
import 'tizen_sdk.dart';
import 'tizen_tpk.dart';

/// Prepares the pre-built flutter bundle.
///
/// Source: [AndroidAssetBundle] in `android.dart`
abstract class TizenAssetBundle extends Target {
  const TizenAssetBundle();

  @override
  String get name => 'tizen_asset_bundle';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.dill'),
        ...IconTreeShaker.inputs,
      ];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  List<String> get depfiles => <String>[
        'flutter_assets.d',
      ];

  @override
  List<Target> get dependencies => const <Target>[
        KernelSnapshot(),
      ];

  @override
  Future<void> build(Environment environment) async {
    if (environment.defines[kBuildMode] == null) {
      throw MissingDefineException(kBuildMode, name);
    }
    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);
    final Directory outputDirectory = environment.outputDir
        .childDirectory('flutter_assets')
          ..createSync(recursive: true);

    // Only copy the prebuilt runtimes and kernel blob in debug mode.
    if (buildMode == BuildMode.debug) {
      final String vmSnapshotData = environment.artifacts
          .getArtifactPath(Artifact.vmSnapshotData, mode: BuildMode.debug);
      final String isolateSnapshotData = environment.artifacts
          .getArtifactPath(Artifact.isolateSnapshotData, mode: BuildMode.debug);
      environment.buildDir
          .childFile('app.dill')
          .copySync(outputDirectory.childFile('kernel_blob.bin').path);
      environment.fileSystem
          .file(vmSnapshotData)
          .copySync(outputDirectory.childFile('vm_snapshot_data').path);
      environment.fileSystem
          .file(isolateSnapshotData)
          .copySync(outputDirectory.childFile('isolate_snapshot_data').path);
    }
    final Depfile assetDepfile = await copyAssets(
      environment,
      outputDirectory,
      targetPlatform: TargetPlatform.android,
    );
    final DepfileService depfileService = DepfileService(
      fileSystem: environment.fileSystem,
      logger: environment.logger,
    );
    depfileService.writeToFile(
      assetDepfile,
      environment.buildDir.childFile('flutter_assets.d'),
    );
  }
}

/// Source: [DebugAndroidApplication] in `android.dart`
class DebugTizenApplication extends TizenAssetBundle {
  DebugTizenApplication(this.project, this.buildInfo);

  final FlutterProject project;
  final TizenBuildInfo buildInfo;

  @override
  String get name => 'debug_tizen_application';

  @override
  List<Source> get inputs => <Source>[
        ...super.inputs,
        const Source.artifact(Artifact.vmSnapshotData, mode: BuildMode.debug),
        const Source.artifact(Artifact.isolateSnapshotData,
            mode: BuildMode.debug),
      ];

  @override
  List<Source> get outputs => <Source>[
        ...super.outputs,
        const Source.pattern('{OUTPUT_DIR}/flutter_assets/vm_snapshot_data'),
        const Source.pattern(
            '{OUTPUT_DIR}/flutter_assets/isolate_snapshot_data'),
        const Source.pattern('{OUTPUT_DIR}/flutter_assets/kernel_blob.bin'),
      ];

  @override
  List<Target> get dependencies => <Target>[
        ...super.dependencies,
        if (TizenProject.fromFlutter(project).isDotnet)
          TizenPlugins(project, buildInfo),
      ];
}

/// See: [ReleaseAndroidApplication] in `android.dart`
class ReleaseTizenApplication extends TizenAssetBundle {
  ReleaseTizenApplication(this.project, this.buildInfo);

  final FlutterProject project;
  final TizenBuildInfo buildInfo;

  @override
  String get name => 'release_tizen_application';

  @override
  List<Target> get dependencies => <Target>[
        ...super.dependencies,
        TizenAotElf(),
        if (TizenProject.fromFlutter(project).isDotnet)
          TizenPlugins(project, buildInfo),
      ];
}

/// Compiles Tizen native plugins into shared objects.
class TizenPlugins extends Target {
  TizenPlugins(this.project, this.buildInfo);

  final FlutterProject project;
  final TizenBuildInfo buildInfo;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  @override
  String get name => 'tizen_plugins';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{PROJECT_DIR}/.packages'),
      ];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  List<String> get depfiles => <String>[
        'tizen_plugins.d',
      ];

  @override
  List<Target> get dependencies => const <Target>[];

  @override
  Future<void> build(Environment environment) async {
    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);

    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    final String profile =
        TizenManifest.parseFromXml(tizenProject.manifestFile)?.profile;

    // Clear the output directory.
    final Directory ephemeralDir = tizenProject.ephemeralDirectory;
    if (ephemeralDir.existsSync()) {
      ephemeralDir.deleteSync(recursive: true);
    }
    ephemeralDir.createSync(recursive: true);

    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, nativeOnly: true);

    for (final TizenPlugin plugin in nativePlugins) {
      final Directory pluginDir = environment.fileSystem.directory(plugin.path);
      final String buildConfig = buildMode.isPrecompiled ? 'Release' : 'Debug';
      final Directory buildDir = pluginDir.childDirectory(buildConfig);

      final Directory engineDir =
          tizenArtifacts.getEngineDirectory(buildInfo.targetArch, buildMode);
      final Directory commonDir = engineDir.parent.childDirectory('common');
      final Directory clientWrapperDir =
          commonDir.childDirectory('cpp_client_wrapper');

      if (!engineDir.existsSync() || !clientWrapperDir.existsSync()) {
        throwToolExit(
          'The flutter engine artifacts were corrupted or invalid.\n'
          'Unable to build ${plugin.name} plugin.',
        );
      }
      final Map<String, String> variables = <String, String>{
        'PATH': getDefaultPathVariable(),
        'USER_SRCS': getUnixPath(clientWrapperDir.childFile('*.cc').path)
      };
      final List<String> extraOptions = <String>[
        '-lflutter_tizen_${buildInfo.deviceProfile}',
        '-L${getUnixPath(engineDir.path)}',
        '-std=c++17',
        '-I${getUnixPath(clientWrapperDir.childDirectory('include').path)}',
        '-I${getUnixPath(commonDir.childDirectory('public').path)}',
        '-D${buildInfo.deviceProfile.toUpperCase()}_PROFILE',
      ];

      assert(tizenSdk != null);
      final Rootstrap rootstrap = tizenSdk.getFlutterRootstrap(
          profile: profile, arch: buildInfo.targetArch);

      if (buildDir.existsSync()) {
        buildDir.deleteSync(recursive: true);
      }
      final RunResult result = await _processUtils.run(<String>[
        tizenSdk.tizenCli.path,
        'build-native',
        '-a',
        getTizenCliArch(buildInfo.targetArch),
        '-C',
        buildConfig,
        '-c',
        tizenSdk.defaultNativeCompiler,
        '-r',
        rootstrap.id,
        '-e',
        extraOptions.join(' '),
        '--',
        pluginDir.path,
      ], environment: variables);
      if (result.exitCode != 0) {
        throwToolExit('Failed to build ${plugin.name} plugin:\n$result');
      }

      final File sharedLib =
          buildDir.childFile('lib' + (plugin.toMap()['sofile'] as String));
      if (!sharedLib.existsSync()) {
        throwToolExit(
          'Built ${plugin.name} but the file ${sharedLib.path} is not found:\n'
          '${result.stdout}',
        );
      }
      final Directory outputDir = ephemeralDir.childDirectory('lib')
        ..createSync(recursive: true);
      sharedLib.copySync(outputDir.childFile(sharedLib.basename).path);

      // Copy binaries that the plugin depends on.
      final Directory pluginLibDir = pluginDir
          .childDirectory('lib')
          .childDirectory(getTizenBuildArch(buildInfo.targetArch));
      if (pluginLibDir.existsSync()) {
        globals.fsUtils.copyDirectorySync(pluginLibDir, outputDir);
      }
    }

    final Depfile pluginDepfile = await _createDepfile(environment);
    final DepfileService depfileService = DepfileService(
      fileSystem: environment.fileSystem,
      logger: environment.logger,
    );
    depfileService.writeToFile(
      pluginDepfile,
      environment.buildDir.childFile('tizen_plugins.d'),
    );
  }

  // Helper method that creates a depfile which lists dependent input files
  // and the generated output binary from the build() process.
  // The files collected here should be synced with the files used and created in compiling.
  //
  // TODO(HakkyuKim): Refactor so that this method doesn't duplicate codes in
  // the build() method without mixing the code lines between two method.
  Future<Depfile> _createDepfile(Environment environment) async {
    final List<File> inputs = <File>[];
    final List<File> outputs = <File>[];

    final Directory commonDir =
        tizenArtifacts.getArtifactDirectory('engine').childDirectory('common');
    final Directory clientWrapperDir =
        commonDir.childDirectory('cpp_client_wrapper');
    final Directory publicDir = commonDir.childDirectory('public');

    clientWrapperDir
        .listSync(recursive: true)
        .whereType<File>()
        .forEach((File file) => inputs.add(file));
    publicDir
        .listSync(recursive: true)
        .whereType<File>()
        .forEach((File file) => inputs.add(file));

    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    final String profile =
        TizenManifest.parseFromXml(tizenProject.manifestFile)?.profile;
    inputs.add(tizenProject.manifestFile);

    final Directory engineDir = tizenArtifacts.getEngineDirectory(
        buildInfo.targetArch, buildInfo.buildInfo.mode);
    final File embedder =
        engineDir.childFile('libflutter_tizen_${buildInfo.deviceProfile}.so');
    inputs.add(embedder);

    final Rootstrap rootstrap = tizenSdk.getFlutterRootstrap(
        profile: profile, arch: buildInfo.targetArch);
    inputs.add(rootstrap.manifestFile);

    final Directory ephemeralDir = tizenProject.ephemeralDirectory;

    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, nativeOnly: true);

    for (final TizenPlugin plugin in nativePlugins) {
      final Directory pluginDir = environment.fileSystem.directory(plugin.path);
      final Directory headerDir = pluginDir.childDirectory('inc');
      final Directory sourceDir = pluginDir.childDirectory('src');

      inputs.add(pluginDir.childFile('project_def.prop'));
      if (headerDir.existsSync()) {
        headerDir
            .listSync(recursive: true)
            .whereType<File>()
            .forEach((File file) => inputs.add(file));
      }
      if (sourceDir.existsSync()) {
        sourceDir
            .listSync(recursive: true)
            .whereType<File>()
            .forEach((File file) => inputs.add(file));
      }

      final File sharedLib = ephemeralDir
          .childDirectory('lib')
          .childFile('lib' + (plugin.toMap()['sofile'] as String));
      outputs.add(sharedLib);

      final Directory pluginLibDir = pluginDir
          .childDirectory('lib')
          .childDirectory(getTizenBuildArch(buildInfo.targetArch));
      if (pluginLibDir.existsSync()) {
        final List<File> pluginLibFiles =
            pluginLibDir.listSync(recursive: true).whereType<File>().toList();
        for (final File file in pluginLibFiles) {
          inputs.add(file);
          final String relativePath =
              file.path.replaceFirst('${pluginLibDir.path}/', '');
          final String outputPath = environment.fileSystem.path.join(
            ephemeralDir.childDirectory('lib').path,
            relativePath,
          );
          outputs.add(environment.fileSystem.file(outputPath));
        }
      }
    }
    return Depfile(inputs, outputs);
  }
}

class DotnetTpk {
  DotnetTpk(this.project, this.buildInfo);

  final FlutterProject project;
  final TizenBuildInfo buildInfo;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  Future<void> build(Environment environment) async {
    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);

    final Directory outputDir = environment.outputDir;
    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    final Directory ephemeralDir = tizenProject.ephemeralDirectory;
    final Directory resDir = ephemeralDir.childDirectory('res');
    final Directory flutterAssetsDir = resDir.childDirectory('flutter_assets');

    if (flutterAssetsDir.existsSync()) {
      flutterAssetsDir.deleteSync(recursive: true);
    }
    globals.fsUtils.copyDirectorySync(
        outputDir.childDirectory('flutter_assets'), flutterAssetsDir);

    final Directory libDir = ephemeralDir.childDirectory('lib')
      ..createSync(recursive: true);

    final Directory engineDir =
        tizenArtifacts.getEngineDirectory(buildInfo.targetArch, buildMode);
    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedder =
        engineDir.childFile('libflutter_tizen_${buildInfo.deviceProfile}.so');
    final File icuData = engineDir.parent
        .childDirectory('common')
        .childDirectory('icu')
        .childFile('icudtl.dat');

    engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
    // The embedder so name is statically defined in C# code and cannot be
    // provided at runtime, so the file name must be fixed.
    embedder.copySync(libDir.childFile('libflutter_tizen.so').path);
    icuData.copySync(resDir.childFile(icuData.basename).path);

    if (buildMode.isPrecompiled) {
      final File aotSharedLib = environment.buildDir.childFile('app.so');
      aotSharedLib.copySync(libDir.childFile('libapp.so').path);
    }

    // Keep this value in sync with the latest published nuget version.
    const String embeddingVersion = '1.6.0';

    // Clear tpkroot directory
    final Directory tpkRootDir = outputDir.childDirectory('tpkroot');
    if (tpkRootDir.existsSync()) {
      tpkRootDir.deleteSync(recursive: true);
    }

    // Run .NET build.
    if (dotnetCli == null) {
      throwToolExit(
        'Unable to locate .NET CLI executable.\n'
        'Install the latest .NET SDK from: https://dotnet.microsoft.com/download',
      );
    }
    RunResult result = await _processUtils.run(<String>[
      dotnetCli.path,
      'build',
      '-c',
      'Release',
      '-o',
      '${outputDir.path}/', // The trailing '/' is needed.
      '/p:FlutterEmbeddingVersion=$embeddingVersion',
      tizenProject.editableDirectory.path,
    ]);
    if (result.exitCode != 0) {
      throwToolExit('Failed to build .NET application:\n$result');
    }

    if (!outputDir.childFile(tizenProject.outputTpkName).existsSync()) {
      throwToolExit(
          'Build succeeded but the expected TPK not found:\n${result.stdout}');
    }

    // build-task-tizen signs the output TPK with a dummy profile by default.
    // We need to re-generate the TPK by signing with a correct profile.
    // TODO(swift-kim): Apply the profile during .NET build for efficiency.
    // Password descryption by secret-tool will be needed for full automation.
    String securityProfile = buildInfo.securityProfile;
    assert(tizenSdk != null);

    if (securityProfile != null) {
      if (tizenSdk.securityProfiles == null ||
          !tizenSdk.securityProfiles.names.contains(securityProfile)) {
        throwToolExit('The profile $securityProfile does not exist.');
      }
    }
    securityProfile ??= tizenSdk.securityProfiles?.active?.name;

    if (securityProfile != null) {
      environment.logger
          .printStatus('The $securityProfile profile is used for signing.');
      result = await _processUtils.run(<String>[
        tizenSdk.tizenCli.path,
        'package',
        '-t',
        'tpk',
        '-s',
        securityProfile,
        '--',
        outputDir.childFile(tizenProject.outputTpkName).path,
      ]);
      if (result.exitCode != 0) {
        throwToolExit('Failed to sign the TPK:\n$result');
      }
    } else {
      environment.logger.printStatus(
        'The tpk has been signed with a default certificate. You can create one using Certificate Manager.\n'
        'https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/install-tizen-sdk.md#create-a-tizen-certificate',
        color: TerminalColor.yellow,
      );
    }
  }
}

/// Generates an AOT snapshot (app.so) of the Dart code.
///
/// Source: [AotElfRelease] in `common.dart`
class TizenAotElf extends AotElfBase {
  TizenAotElf();

  @override
  String get name => 'tizen_aot_elf';

  @override
  List<Source> get inputs => <Source>[
        const Source.pattern('{BUILD_DIR}/app.dill'),
        const Source.artifact(Artifact.engineDartBinary),
        const Source.artifact(Artifact.skyEnginePath),
        // Any type of gen_snapshot is applicable here because engine artifacts
        // are assumed to be updated at once, not one by one for each platform
        // or build mode.
        const Source.artifact(Artifact.genSnapshot, mode: BuildMode.release),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.so'),
      ];

  @override
  List<Target> get dependencies => const <Target>[
        KernelSnapshot(),
      ];
}

class NativeTpk {
  NativeTpk(this.project, this.buildInfo);

  final FlutterProject project;
  final TizenBuildInfo buildInfo;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  Future<void> build(Environment environment) async {
    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);

    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    final String profile =
        TizenManifest.parseFromXml(tizenProject.manifestFile)?.profile;

    // Copy ephemeral files.
    // TODO(swift-kim): Use ephemeral directory instead of editable directory.
    final Directory outputDir = environment.outputDir;
    final Directory tizenDir = tizenProject.editableDirectory;
    final Directory resDir = tizenDir.childDirectory('res')
      ..createSync(recursive: true);
    if (resDir.childDirectory('flutter_assets').existsSync()) {
      resDir.childDirectory('flutter_assets').deleteSync(recursive: true);
    }
    globals.fsUtils.copyDirectorySync(
        outputDir.childDirectory('flutter_assets'),
        resDir.childDirectory('flutter_assets'));

    final Directory libDir = tizenDir.childDirectory('lib')
      ..createSync(recursive: true);

    final Directory engineDir =
        tizenArtifacts.getEngineDirectory(buildInfo.targetArch, buildMode);
    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedder =
        engineDir.childFile('libflutter_tizen_${buildInfo.deviceProfile}.so');
    final File icuData = engineDir.parent
        .childDirectory('common')
        .childDirectory('icu')
        .childFile('icudtl.dat');

    engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
    embedder.copySync(libDir.childFile(embedder.basename).path);
    icuData.copySync(resDir.childFile(icuData.basename).path);

    if (libDir.childFile('libapp.so').existsSync()) {
      libDir.childFile('libapp.so').deleteSync(recursive: true);
    }
    if (buildMode.isPrecompiled) {
      final File aotSharedLib = environment.buildDir.childFile('app.so');
      aotSharedLib.copySync(libDir.childFile('libapp.so').path);
    }

    // Prepare for build.
    final String buildConfig = buildMode.isPrecompiled ? 'Release' : 'Debug';
    final Directory buildDir = tizenDir.childDirectory(buildConfig);
    final Directory embeddingDir = environment.fileSystem
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('embedding')
        .childDirectory('cpp');

    final List<String> userIncludes = <String>[
      embeddingDir.childDirectory('include').path,
    ];
    final List<String> userSources = <String>[
      embeddingDir.childFile('*.cc').path,
    ];
    final List<String> userLibs = <String>[];

    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, nativeOnly: true);

    for (final TizenPlugin plugin in nativePlugins) {
      final TizenLibrary library = TizenLibrary(plugin.path);
      // TODO(swift-kim): Currently only checks for USER_INC_DIRS, USER_SRCS,
      // and USER_LIBS. More properties should be parsed to fully support
      // plugin builds.
      userIncludes.addAll(library.getPropertyAsAbsolutePaths('USER_INC_DIRS'));
      userSources.addAll(library.getPropertyAsAbsolutePaths('USER_SRCS'));

      for (final String userLib
          in library.getProperty('USER_LIBS').split(' ')) {
        final File libFile = library.directory
            .childDirectory('lib')
            .childDirectory(getTizenBuildArch(buildInfo.targetArch))
            .childFile('lib$userLib.so');
        if (libFile.existsSync()) {
          libFile.copySync(libDir.childFile(libFile.basename).path);
          userLibs.add(userLib);
        }
      }
    }

    final Directory commonDir = engineDir.parent.childDirectory('common');
    final Directory clientWrapperDir =
        commonDir.childDirectory('cpp_client_wrapper');
    userSources.add(clientWrapperDir.childFile('*.cc').path);

    if (!engineDir.existsSync() || !clientWrapperDir.existsSync()) {
      throwToolExit('The flutter engine artifacts were corrupted or invalid.');
    }
    final Map<String, String> variables = <String, String>{
      'PATH': getDefaultPathVariable(),
      'USER_SRCS': userSources.map(getUnixPath).join(' '),
    };
    final List<String> extraOptions = <String>[
      '-lflutter_tizen_${buildInfo.deviceProfile}',
      '-L${getUnixPath(libDir.path)}',
      '-std=c++17',
      '-I${getUnixPath(clientWrapperDir.childDirectory('include').path)}',
      '-I${getUnixPath(commonDir.childDirectory('public').path)}',
      ...userIncludes.map(getUnixPath).map((String p) => '-I' + p),
      ...userLibs.map((String lib) => '-l' + lib),
      '-D${buildInfo.deviceProfile.toUpperCase()}_PROFILE',
      '-Wl,-unresolved-symbols=ignore-in-shared-libs',
    ];

    assert(tizenSdk != null);
    final Rootstrap rootstrap = tizenSdk.getFlutterRootstrap(
        profile: profile, arch: buildInfo.targetArch);

    // Run native build.
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }
    RunResult result = await _processUtils.run(<String>[
      tizenSdk.tizenCli.path,
      'build-native',
      '-a',
      getTizenCliArch(buildInfo.targetArch),
      '-C',
      buildConfig,
      '-c',
      tizenSdk.defaultNativeCompiler,
      '-r',
      rootstrap.id,
      '-e',
      extraOptions.join(' '),
      '--',
      tizenDir.path,
    ], environment: variables);
    if (result.exitCode != 0) {
      throwToolExit('Failed to compile native application:\n$result');
    }
    result = await _processUtils.run(<String>[
      tizenSdk.tizenCli.path,
      'package',
      '-t',
      'tpk',
      if (buildInfo.securityProfile?.isNotEmpty ?? false) ...<String>[
        '-s',
        buildInfo.securityProfile,
      ],
      '--',
      buildDir.path,
    ]);
    if (result.exitCode != 0) {
      throwToolExit('Failed to generate TPK:\n$result');
    }

    final String tpkArch = buildInfo.targetArch
        .replaceFirst('arm64', 'aarch64')
        .replaceFirst('x86', 'i586');
    final String nativeTpkName =
        tizenProject.outputTpkName.replaceFirst('.tpk', '-$tpkArch.tpk');
    if (buildDir.childFile(nativeTpkName).existsSync()) {
      buildDir
          .childFile(nativeTpkName)
          .renameSync(outputDir.childFile(tizenProject.outputTpkName).path);
    } else {
      throwToolExit(
          'Build succeeded but the expected TPK not found:\n${result.stdout}');
    }
  }
}

/// Converts [targetArch] to an arch name that the Tizen CLI expects.
String getTizenCliArch(String targetArch) {
  switch (targetArch) {
    case 'arm64':
      return 'aarch64';
    default:
      return targetArch;
  }
}

/// Converts [targetArch] to an arch name that corresponds to the `BUILD_ARCH`
/// value used by the Tizen native builder.
String getTizenBuildArch(String targetArch) {
  switch (targetArch) {
    case 'arm':
      return 'armel';
    case 'arm64':
      return 'aarch64';
    case 'x86':
      return 'i586';
    default:
      return targetArch;
  }
}

/// On non-Windows, returns [path] unchanged.
///
/// On Windows, converts Windows-style [path] (e.g. 'C:\x\y') into Unix path
/// ('/c/x/y') and returns.
String getUnixPath(String path) {
  if (!Platform.isWindows) {
    return path;
  }
  path = path.replaceAll(r'\', '/');
  if (path.startsWith(':', 1)) {
    return '/${path[0].toLowerCase()}${path.substring(2)}';
  }
  return path;
}

/// On non-Windows, returns the PATH environment variable.
///
/// On Windows, appends the msys2 executables directory to PATH and returns.
String getDefaultPathVariable() {
  final Map<String, String> variables = globals.platform.environment;
  String path = variables.containsKey('PATH') ? variables['PATH'] : '';
  if (Platform.isWindows) {
    assert(tizenSdk != null);
    final String msysUsrBin = tizenSdk.toolsDirectory
        .childDirectory('msys2')
        .childDirectory('usr')
        .childDirectory('bin')
        .path;
    path += ';$msysUsrBin';
  }
  return path;
}
