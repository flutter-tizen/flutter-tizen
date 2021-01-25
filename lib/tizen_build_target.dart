// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tizen/tizen_tpk.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/build.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/exceptions.dart';
import 'package:flutter_tools/src/build_system/source.dart';
import 'package:flutter_tools/src/build_system/targets/android.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

import 'tizen_artifacts.dart';
import 'tizen_builder.dart';
import 'tizen_plugins.dart';
import 'tizen_project.dart';
import 'tizen_sdk.dart';

/// Prepares the pre-built flutter bundle.
class TizenAssetBundle extends AndroidAssetBundle {
  @override
  String get name => 'tizen_asset_bundle';
}

/// Compiles Tizen native plugins into shared objects.
class TizenPlugins extends Target {
  TizenPlugins(this.project, this.targetArchs);

  final FlutterProject project;
  final List<String> targetArchs;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  @override
  String get name => 'tizen_plugins';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{PROJECT_DIR}/.packages'),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{PROJECT_DIR}/tizen/flutter/ephemeral'),
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
        await findTizenPlugins(project, filterNative: true);

    for (final TizenPlugin plugin in nativePlugins) {
      final Directory pluginDir = environment.fileSystem.directory(plugin.path);
      final String buildConfig = buildMode.isPrecompiled ? 'Release' : 'Debug';
      final Directory buildDir = pluginDir.childDirectory(buildConfig);
      final File sharedLib =
          buildDir.childFile('lib' + (plugin.toMap()['sofile'] as String));

      for (final String arch in targetArchs) {
        final Directory engineDir = tizenArtifacts.getEngineDirectory(
            getTargetPlatformForArch(arch), buildMode);
        final Directory commonDir = engineDir.parent.childDirectory('common');
        final Directory clientWrapperDir =
            commonDir.childDirectory('client_wrapper');

        if (!engineDir.existsSync() || !clientWrapperDir.existsSync()) {
          throwToolExit(
            'The flutter engine artifacts were corrupted or invalid.\n'
            'Unable to build ${plugin.name} plugin.',
          );
        }
        final Map<String, String> variables = <String, String>{
          'USER_SRCS': clientWrapperDir.childFile('*.cc').path
        };
        final List<String> extraOptions = <String>[
          '-lflutter_tizen',
          '-L${engineDir.path}',
          '-I${clientWrapperDir.childDirectory('include').path}',
          '-I${commonDir.childDirectory('public').path}'
        ];

        if (getTizenCliPath() == null) {
          throwToolExit(
            'Unable to locate Tizen SDK.\n'
            'Run "flutter-tizen doctor" and install required components.',
          );
        }
        if (buildDir.existsSync()) {
          buildDir.deleteSync(recursive: true);
        }
        final RunResult result = await _processUtils.run(<String>[
          getTizenCliPath(),
          'build-native',
          '-a',
          arch,
          '-C',
          buildConfig,
          '-c',
          tizenSdk.defaultNativeCompiler,
          '-r',
          tizenSdk.getFlutterRootstrap(profile: profile, arch: arch),
          '-e',
          extraOptions.join(' '),
          '--',
          pluginDir.path,
        ], environment: variables);
        if (result.exitCode != 0) {
          throwToolExit('Failed to build ${plugin.name} plugin:\n$result');
        }

        if (!sharedLib.existsSync()) {
          throwToolExit(
            'Built ${plugin.name} but the file ${sharedLib.path} is not found:\n'
            '${result.stdout}',
          );
        }
        final Directory outputDir = ephemeralDir
            .childDirectory('lib')
            .childDirectory(arch)
              ..createSync(recursive: true);
        sharedLib.copySync(outputDir.childFile(sharedLib.basename).path);
      }
    }
  }
}

abstract class DotnetTpk extends Target {
  DotnetTpk(this.project, this.buildInfo);

  final FlutterProject project;
  final TizenBuildInfo buildInfo;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{PROJECT_DIR}/tizen'),
        Source.pattern('{OUTPUT_DIR}/flutter_assets'),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{OUTPUT_DIR}/*.tpk'),
      ];

  @override
  List<Target> get dependencies => <Target>[
        TizenAssetBundle(),
        TizenPlugins(project, buildInfo.targetArchs),
      ];

  @override
  Future<void> build(Environment environment) async {
    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);

    // Copy ephemeral files.
    final Directory outputDir = environment.outputDir;
    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    final Directory ephemeralDir = tizenProject.ephemeralDirectory;
    final Directory resDir = ephemeralDir.childDirectory('res')
      ..createSync(recursive: true);
    globals.fsUtils.copyDirectorySync(
        outputDir.childDirectory('flutter_assets'),
        resDir.childDirectory('flutter_assets'));

    for (final String arch in buildInfo.targetArchs) {
      final Directory libDir = ephemeralDir
          .childDirectory('lib')
          .childDirectory(arch)
            ..createSync(recursive: true);

      final Directory engineDir = tizenArtifacts.getEngineDirectory(
          getTargetPlatformForArch(arch), buildMode);
      final File engineBinary = engineDir.childFile('libflutter_engine.so');
      final File embedding = engineDir.childFile('libflutter_tizen.so');
      final File icuData =
          engineDir.parent.childDirectory('common').childFile('icudtl.dat');

      engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
      embedding.copySync(libDir.childFile(embedding.basename).path);
      icuData.copySync(resDir.childFile(icuData.basename).path);

      if (tizenProject.apiVersion.startsWith('4')) {
        final File embedding40 = engineDir.childFile('libflutter_tizen40.so');
        embedding40.copySync(libDir.childFile(embedding40.basename).path);
      }
      if (buildMode.isPrecompiled) {
        final File aotSharedLib =
            environment.buildDir.childDirectory(arch).childFile('app.so');
        aotSharedLib.copySync(libDir.childFile('libapp.so').path);
      }
    }

    // For now a constant value is used instead of reading from a file.
    // Keep this value in sync with the latest published nuget version.
    const String embeddingVersion = '1.2.0';

    // Run .NET build.
    if (getDotnetCliPath() == null) {
      throwToolExit('Unable to locate .NET CLI.');
    }
    RunResult result = await _processUtils.run(<String>[
      getDotnetCliPath(),
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

    if (getTizenCliPath() == null) {
      throwToolExit(
        'Unable to locate Tizen SDK.\n'
        'Run "flutter-tizen doctor" and install required components.',
      );
    }
    // build-task-tizen signs the output TPK with a dummy profile by default.
    // We need to re-generate the TPK by signing with a correct profile.
    // TODO(swift-kim): Apply the profile during .NET build for efficiency.
    // Password descryption by secret-tool will be needed for full automation.
    if (buildInfo.securityProfile?.isEmpty ?? true) {
      environment.logger.printStatus('The active profile is used for signing.');
    }
    result = await _processUtils.run(<String>[
      getTizenCliPath(),
      'package',
      '-t',
      'tpk',
      if (buildInfo.securityProfile?.isNotEmpty ?? false) ...<String>[
        '-s',
        buildInfo.securityProfile,
      ],
      '--',
      outputDir.childFile(tizenProject.outputTpkName).path,
    ]);
    if (result.exitCode != 0) {
      throwToolExit('Failed to sign the TPK:\n$result');
    }
  }
}

/// Builds AOT snapshots (app.so) for multiple target archs.
///
/// Source: [AotElfBase] in `common.dart`
class TizenAotElf extends Target {
  TizenAotElf(this.targetArchs);

  final List<String> targetArchs;

  @override
  String get name => 'tizen_aot_elf';

  /// Source: [AotElfProfile.inputs] in `common.dart`
  @override
  List<Source> get inputs => <Source>[
        const Source.pattern('{BUILD_DIR}/app.dill'),
        const Source.pattern('{PROJECT_DIR}/.packages'),
        const Source.artifact(Artifact.engineDartBinary),
        const Source.artifact(Artifact.skyEnginePath),
        const Source.artifact(Artifact.genSnapshot, mode: BuildMode.release),
      ];

  @override
  List<Source> get outputs => <Source>[
        ...targetArchs
            .map((String arch) => Source.pattern('{BUILD_DIR}/$arch/app.so')),
      ];

  @override
  List<Target> get dependencies => const <Target>[
        KernelSnapshot(),
      ];

  @override
  Future<void> build(Environment environment) async {
    final AOTSnapshotter snapshotter = AOTSnapshotter(
      reportTimings: false,
      fileSystem: environment.fileSystem,
      logger: environment.logger,
      xcode: null,
      processManager: environment.processManager,
      artifacts: environment.artifacts,
    );
    if (environment.defines[kBuildMode] == null) {
      throw MissingDefineException(kBuildMode, 'aot_elf');
    }
    if (environment.defines[kTargetPlatform] == null) {
      throw MissingDefineException(kTargetPlatform, 'aot_elf');
    }
    final List<String> extraGenSnapshotOptions =
        decodeDartDefines(environment.defines, kExtraGenSnapshotOptions);
    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);
    final String splitDebugInfo = environment.defines[kSplitDebugInfo];
    final bool dartObfuscation =
        environment.defines[kDartObfuscation] == 'true';
    final String codeSizeDirectory = environment.defines[kCodeSizeDirectory];

    // targetArchs.length always equals to 1.
    if (codeSizeDirectory != null) {
      final File codeSizeFile = environment.fileSystem
          .directory(codeSizeDirectory)
          .childFile('snapshot.${targetArchs.first}.json');
      final File precompilerTraceFile = environment.fileSystem
          .directory(codeSizeDirectory)
          .childFile('trace.${targetArchs.first}.json');
      extraGenSnapshotOptions
          .add('--write-v8-snapshot-profile-to=${codeSizeFile.path}');
      extraGenSnapshotOptions
          .add('--trace-precompiler-to=${precompilerTraceFile.path}');
    }

    for (final String arch in targetArchs) {
      final TargetPlatform platform = getTargetPlatformForArch(arch);
      final String outputPath = environment.buildDir.childDirectory(arch).path;
      final int snapshotExitCode = await snapshotter.build(
        platform: platform,
        buildMode: buildMode,
        mainPath: environment.buildDir.childFile('app.dill').path,
        packagesPath: environment.projectDir.childFile('.packages').path,
        outputPath: outputPath,
        bitcode: false,
        extraGenSnapshotOptions: extraGenSnapshotOptions,
        splitDebugInfo: splitDebugInfo,
        dartObfuscation: dartObfuscation,
      );
      if (snapshotExitCode != 0) {
        throw Exception('AOT snapshotter exited with code $snapshotExitCode');
      }
    }
  }
}

/// Source: [DebugAndroidApplication] in `android.dart`
class DebugDotnetTpk extends DotnetTpk {
  DebugDotnetTpk(FlutterProject project, TizenBuildInfo buildInfo)
      : super(project, buildInfo);

  @override
  String get name => 'debug_dotnet_tpk';

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
}

/// See: [ReleaseAndroidApplication] in `android.dart`
class ReleaseDotnetTpk extends DotnetTpk {
  ReleaseDotnetTpk(FlutterProject project, TizenBuildInfo buildInfo)
      : super(project, buildInfo);

  @override
  String get name => 'release_dotnet_tpk';

  @override
  List<Target> get dependencies => <Target>[
        TizenAotElf(buildInfo.targetArchs),
        ...super.dependencies,
      ];
}

abstract class NativeTpk extends Target {
  NativeTpk(this.project, this.buildInfo);

  final FlutterProject project;
  final TizenBuildInfo buildInfo;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{PROJECT_DIR}/tizen'),
        Source.pattern('{OUTPUT_DIR}/flutter_assets'),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{OUTPUT_DIR}/*.tpk'),
      ];

  @override
  List<Target> get dependencies => <Target>[
        TizenAssetBundle(),
      ];

  @override
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

    assert(buildInfo.targetArchs.length == 1);
    final String targetArch = buildInfo.targetArchs.first;
    final Directory libDir = tizenDir.childDirectory('lib')
      ..createSync(recursive: true);

    final Directory engineDir = tizenArtifacts.getEngineDirectory(
        getTargetPlatformForArch(targetArch), buildMode);
    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedding = engineDir.childFile('libflutter_tizen.so');
    final File icuData =
        engineDir.parent.childDirectory('common').childFile('icudtl.dat');

    engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
    embedding.copySync(libDir.childFile(embedding.basename).path);
    icuData.copySync(resDir.childFile(icuData.basename).path);

    if (libDir.childFile('libapp.so').existsSync()) {
      libDir.childFile('libapp.so').deleteSync(recursive: true);
    }
    if (buildMode.isPrecompiled) {
      final File aotSharedLib =
          environment.buildDir.childDirectory(targetArch).childFile('app.so');
      aotSharedLib.copySync(libDir.childFile('libapp.so').path);
    }

    // Prepare for build.
    final String buildConfig = buildMode.isPrecompiled ? 'Release' : 'Debug';
    final Directory buildDir = tizenDir.childDirectory(buildConfig);

    final List<String> userIncludes = <String>[];
    final List<String> userSources = <String>[];

    final List<TizenPlugin> plugins =
        await findTizenPlugins(project, filterNative: true);
    for (final TizenPlugin plugin in plugins) {
      final TizenNativeProject pluginProject = TizenNativeProject(plugin.path);
      // TODO(swift-kim): Currently only checks for USER_INC_DIRS and USER_SRCS.
      // More properties (such as USER_LIBS) should be parsed to fully support
      // plugin builds.
      userIncludes
          .addAll(pluginProject.getPropertyAsAbsolutePaths('USER_INC_DIRS'));
      userSources.addAll(pluginProject.getPropertyAsAbsolutePaths('USER_SRCS'));
    }

    final Directory commonDir = engineDir.parent.childDirectory('common');
    final Directory clientWrapperDir =
        commonDir.childDirectory('client_wrapper');
    userSources.add(clientWrapperDir.childFile('*.cc').path);

    if (!engineDir.existsSync() || !clientWrapperDir.existsSync()) {
      throwToolExit('The flutter engine artifacts were corrupted or invalid.');
    }
    final Map<String, String> variables = <String, String>{
      'USER_SRCS': userSources.join(' '),
    };
    final List<String> extraOptions = <String>[
      '-lflutter_tizen',
      '-L${libDir.path}',
      '-I${clientWrapperDir.childDirectory('include').path}',
      '-I${commonDir.childDirectory('public').path}',
      ...userIncludes.map((String p) => '-I' + p),
      '-Wl,-unresolved-symbols=ignore-in-shared-libs',
    ];

    // Run native build.
    if (getTizenCliPath() == null) {
      throwToolExit(
        'Unable to locate Tizen SDK.\n'
        'Run "flutter-tizen doctor" and install required components.',
      );
    }
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }
    RunResult result = await _processUtils.run(<String>[
      getTizenCliPath(),
      'build-native',
      '-a',
      targetArch,
      '-C',
      buildConfig,
      '-c',
      tizenSdk.defaultNativeCompiler,
      '-r',
      tizenSdk.getFlutterRootstrap(profile: profile, arch: targetArch),
      '-e',
      extraOptions.join(' '),
      '--',
      tizenDir.path,
    ], environment: variables);
    if (result.exitCode != 0) {
      throwToolExit('Failed to compile native application:\n$result');
    }
    result = await _processUtils.run(<String>[
      getTizenCliPath(),
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

    final String nativeArch = targetArch == 'x86' ? 'i586' : targetArch;
    final String nativeTpkName =
        tizenProject.outputTpkName.replaceFirst('.tpk', '-$nativeArch.tpk');
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

class DebugNativeTpk extends NativeTpk {
  DebugNativeTpk(FlutterProject project, TizenBuildInfo buildInfo)
      : super(project, buildInfo);

  @override
  String get name => 'debug_native_tpk';

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
}

class ReleaseNativeTpk extends NativeTpk {
  ReleaseNativeTpk(FlutterProject project, TizenBuildInfo buildInfo)
      : super(project, buildInfo);

  @override
  String get name => 'release_native_tpk';

  @override
  List<Target> get dependencies => <Target>[
        TizenAotElf(buildInfo.targetArchs),
        ...super.dependencies,
      ];
}
