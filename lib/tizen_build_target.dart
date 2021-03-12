// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/build.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/exceptions.dart';
import 'package:flutter_tools/src/build_system/source.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/targets/icon_tree_shaker.dart';
import 'package:flutter_tools/src/build_system/targets/assets.dart';
import 'package:flutter_tools/src/build_system/targets/android.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/build_system/file_store.dart';

import 'tizen_artifacts.dart';
import 'tizen_builder.dart';
import 'tizen_plugins.dart';
import 'tizen_project.dart';
import 'tizen_sdk.dart';
import 'tizen_tpk.dart';

/// Prepares the pre-built flutter bundle.
/// Source: [AndroidAssetBundle] in `android.dart`
class TizenAssetBundle extends Target {
  TizenAssetBundle(this.project);

  final FlutterProject project;

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
  Future<void> build(Environment environment) async {
    if (environment.defines[kBuildMode] == null) {
      throw MissingDefineException(kBuildMode, name);
    }
    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);

    final TizenProject tizenProject = TizenProject.fromFlutter(project);

    final Directory outputDirectory = tizenProject.ephemeralDirectory
        .childDirectory('res')
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
      targetPlatform: TargetPlatform.tester,
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

  @override
  List<Target> get dependencies => const <Target>[
        KernelSnapshot(),
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
        Source.pattern('{PROJECT_DIR}/.flutter-plugins'),
        Source.pattern('{PROJECT_DIR}/.flutter-plugins-dependencies'),
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
    final List<File> inputs = <File>[];
    final List<File> outputs = <File>[];

    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);

    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    final String profile =
        TizenManifest.parseFromXml(tizenProject.manifestFile)?.profile;

    // Clear the output directory.
    final Directory ephemeralDir = tizenProject.ephemeralDirectory;

    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, nativeOnly: true);

    for (final TizenPlugin plugin in nativePlugins) {
      final Directory pluginDir = environment.fileSystem.directory(plugin.path);
      final String buildConfig = buildMode.isPrecompiled ? 'Release' : 'Debug';
      final Directory buildDir = pluginDir.childDirectory(buildConfig);
      final File sharedLib =
          buildDir.childFile('lib' + (plugin.toMap()['sofile'] as String));

      for (final String arch in buildInfo.targetArchs) {
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
          '-I${commonDir.childDirectory('public').path}',
          '-D${buildInfo.deviceProfile.toUpperCase()}_PROFILE',
        ];

        if (tizenSdk == null || !tizenSdk.tizenCli.existsSync()) {
          throwToolExit(
            'Unable to locate Tizen CLI executable.\n'
            'Run "flutter-tizen doctor" and install required components.',
          );
        }
        if (buildDir.existsSync()) {
          buildDir.deleteSync(recursive: true);
        }
        final RunResult result = await _processUtils.run(<String>[
          tizenSdk.tizenCli.path,
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
        outputs.add(outputDir.childFile(sharedLib.basename));
      }
    }

    final DepfileService depfileService = DepfileService(
      fileSystem: environment.fileSystem,
      logger: environment.logger,
    );
    depfileService.writeToFile(
      Depfile(inputs, outputs),
      environment.buildDir.childFile('tizen_plugins.d'),
    );
  }
}

abstract class TizenPackage extends Target {
  bool _isTpkCached = true;
  String _securityProfile;
  bool get isTpkCached => _isTpkCached;
  Future<void> package(Environment environment);
}

abstract class DotnetTpk extends TizenPackage {
  DotnetTpk(this.project, this.buildInfo);

  final FlutterProject project;
  final TizenBuildInfo buildInfo;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  @override
  List<Source> get inputs => const <Source>[];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{OUTPUT_DIR}/*.tpk'),
      ];

  @override
  List<Target> get dependencies => <Target>[
        TizenAssetBundle(project),
        TizenPlugins(project, buildInfo),
      ];

  @override
  List<String> get depfiles => <String>[
        'dotnet_tpk.d',
      ];

  @override
  Future<void> build(Environment environment) async {
    final TizenProject tizenProject = TizenProject.fromFlutter(project);

    final List<File> inputs = <File>[];
    final List<File> outputs = <File>[
      environment.outputDir.childFile(tizenProject.outputTpkName),
    ];

    final DepfileService depfileService = DepfileService(
      fileSystem: environment.fileSystem,
      logger: environment.logger,
    );
    final File flutterAssetsDep =
        environment.buildDir.childFile('flutter_assets.d');
    if (flutterAssetsDep.existsSync()) {
      final Depfile flutterAssets = depfileService.parse(flutterAssetsDep);
      inputs.addAll(flutterAssets.outputs);
    }
    final File tizenPluginsDep =
        environment.buildDir.childFile('tizen_plugins.d');
    if (tizenPluginsDep.existsSync()) {
      final Depfile tizenPlugins = depfileService.parse(tizenPluginsDep);
      inputs.addAll(tizenPlugins.outputs);
    }

    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);

    // Copy ephemeral files.
    final Directory ephemeralDir = tizenProject.ephemeralDirectory;
    final Directory resDir = ephemeralDir.childDirectory('res')
      ..createSync(recursive: true);

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
      inputs.addAll(<File>[engineBinary, embedding, icuData]);

      engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
      outputs.add(libDir.childFile(engineBinary.basename));
      embedding.copySync(libDir.childFile(embedding.basename).path);
      outputs.add(libDir.childFile(embedding.basename));
      icuData.copySync(resDir.childFile(icuData.basename).path);
      outputs.add(resDir.childFile(icuData.basename));

      if (tizenProject.apiVersion.startsWith('4')) {
        final File embedding40 = engineDir.childFile('libflutter_tizen40.so');
        embedding40.copySync(libDir.childFile(embedding40.basename).path);
        inputs.add(embedding40);
        outputs.add(libDir.childFile(embedding40.basename));
      }
      if (buildMode.isPrecompiled) {
        final File aotSharedLib =
            environment.buildDir.childDirectory(arch).childFile('app.so');
        aotSharedLib.copySync(libDir.childFile('libapp.so').path);
        inputs.add(aotSharedLib);
        outputs.add(libDir.childFile('libapp.so'));
      }
    }

    // add host app files
    final List<Directory> directories = tizenProject.editableDirectory
        .listSync()
        .whereType<Directory>()
        .where((Directory directory) =>
            directory.basename != 'obj' &&
            directory.basename != 'bin' &&
            directory.basename != 'flutter')
        .toList();

    inputs.addAll(<File>[
      // all files in subdirectories of tizen host app root
      // except obj, bin, and flutter. For example, all
      // resoruce files in shared directory must be included
      for (final Directory directory in directories)
        ...directory.listSync(recursive: true).whereType<File>(),
      // all files in host app root, such as App.cs, NuGet.Config, etc
      ...tizenProject.editableDirectory.listSync().whereType<File>(),
      // generated plugin injection codes
      ...tizenProject.editableDirectory
          .childDirectory('flutter')
          .listSync()
          .whereType<File>(),
    ]);

    String securityProfile = buildInfo.securityProfile;
    if (securityProfile != null &&
        (tizenSdk.securityProfiles == null ||
            !tizenSdk.securityProfiles.names.contains(securityProfile))) {
      throwToolExit('The security profile $securityProfile does not exist.');
    }

    // add profiles list file as input dependency
    inputs.add(tizenSdk.securityProfilesFile);
    securityProfile ??= tizenSdk.securityProfiles?.activeProfile?.name;

    if (securityProfile != null) {
      // add signing profile certificates as input dependencies
      final SecurityProfile signingProfile =
          tizenSdk.securityProfiles.getProfile(securityProfile);
      inputs.add(environment.fileSystem.file(signingProfile.authorCertificate.key));
      for (final Certificate certificate
          in signingProfile.distributorCertificates) {
        inputs.add(environment.fileSystem.file(certificate.key));
      }
    } else {
      globals.printStatus(
        'The tpk is signed with a default certificate, you can create one using the certificate manager.\n'
        'https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/install-tizen-sdk.md#create-a-tizen-certificate',
        color: TerminalColor.yellow,
      );
    }

    _isTpkCached = false;
    _securityProfile = securityProfile;

    depfileService.writeToFile(
      Depfile(inputs, outputs),
      environment.buildDir.childFile('dotnet_tpk.d'),
    );
  }

  @override
  Future<void> package(Environment environment) async {
    final FlutterProject flutterProject =
        FlutterProject.fromDirectory(environment.projectDir);
    final TizenProject tizenProject = TizenProject.fromFlutter(flutterProject);
    final Directory outputDir = environment.outputDir;

    // For now a constant value is used instead of reading from a file.
    // Keep this value in sync with the latest published nuget version.
    const String embeddingVersion = '1.2.2';

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

    if (tizenSdk == null || !tizenSdk.tizenCli.existsSync()) {
      throwToolExit(
        'Unable to locate Tizen CLI executable.\n'
        'Run "flutter-tizen doctor" and install required components.',
      );
    }
    // build-task-tizen signs the output TPK with a dummy profile by default.
    // We need to re-generate the TPK by signing with a correct profile.
    // TODO(swift-kim): Apply the profile during .NET build for efficiency.
    // Password descryption by secret-tool will be needed for full automation.
    environment.logger
        .printStatus('The $_securityProfile profile is used for signing.');
    result = await _processUtils.run(<String>[
      tizenSdk.tizenCli.path,
      'package',
      '-t',
      'tpk',
      '-s',
      _securityProfile,
      '--',
      outputDir.childFile(tizenProject.outputTpkName).path,
    ]);
    if (result.exitCode != 0) {
      throwToolExit('Failed to sign the TPK:\n$result');
    }

    await _persistTpkCache(environment);
    _isTpkCached = true;
  }

  Future<void> _persistTpkCache(Environment environment) async{
    final FlutterProject flutterProject =
        FlutterProject.fromDirectory(environment.projectDir);
    final TizenProject tizenProject = TizenProject.fromFlutter(flutterProject);
    final File tpk =
        environment.outputDir.childFile(tizenProject.outputTpkName);

    final File cacheFile = environment.buildDir.childFile(FileStore.kFileCache);
    final FileStore fileCache = FileStore(
      cacheFile: cacheFile,
      logger: environment.logger,
    )..initialize();

    // update tpk hash
    fileCache.currentAssetKeys.addAll(fileCache.previousAssetKeys);
    await fileCache.diffFileList(<File>[tpk]);
    fileCache.persist();
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
        const Source.pattern(
            '{PROJECT_DIR}/tizen/flutter/ephemeral/res/flutter_assets/vm_snapshot_data'),
        const Source.pattern(
            '{PROJECT_DIR}/tizen/flutter/ephemeral/res/flutter_assets/isolate_snapshot_data'),
        const Source.pattern(
            '{PROJECT_DIR}/tizen/flutter/ephemeral/res/flutter_assets/kernel_blob.bin'),
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
        TizenAssetBundle(project),
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

    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, nativeOnly: true);

    for (final TizenPlugin plugin in nativePlugins) {
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
      '-D${buildInfo.deviceProfile.toUpperCase()}_PROFILE',
      '-Wl,-unresolved-symbols=ignore-in-shared-libs',
    ];

    // Run native build.
    if (tizenSdk == null || !tizenSdk.tizenCli.existsSync()) {
      throwToolExit(
        'Unable to locate Tizen CLI executable.\n'
        'Run "flutter-tizen doctor" and install required components.',
      );
    }
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }
    RunResult result = await _processUtils.run(<String>[
      tizenSdk.tizenCli.path,
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
        const Source.pattern(
            '{PROJECT_DIR}/tizen/flutter/ephemeral/res/flutter_assets/vm_snapshot_data'),
        const Source.pattern(
            '{PROJECT_DIR}/tizen/flutter/ephemeral/res/flutter_assets/isolate_snapshot_data'),
        const Source.pattern(
            '{PROJECT_DIR}/tizen/flutter/ephemeral/res/flutter_assets/kernel_blob.bin'),
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
