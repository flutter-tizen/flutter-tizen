// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/exceptions.dart';
import 'package:flutter_tools/src/build_system/targets/android.dart';
import 'package:flutter_tools/src/build_system/targets/assets.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/build_system/targets/icon_tree_shaker.dart';
import 'package:flutter_tools/src/compile.dart';
import 'package:flutter_tools/src/dart/package_map.dart';
import 'package:package_config/src/package_config.dart';

import '../tizen_build_info.dart';
import 'plugins.dart';

class TizenKernelSnapshotProgram extends KernelSnapshot {
  const TizenKernelSnapshotProgram();

  /// Source: [KernelSnapshot.build] in `common.dart`
  @override
  Future<void> build(Environment environment) async {
    final KernelCompiler compiler = KernelCompiler(
      fileSystem: environment.fileSystem,
      logger: environment.logger,
      processManager: environment.processManager,
      artifacts: environment.artifacts,
      fileSystemRoots: <String>[],
    );
    final String? buildModeEnvironment = environment.defines[kBuildMode];
    if (buildModeEnvironment == null) {
      throw MissingDefineException(kBuildMode, 'kernel_snapshot');
    }
    final BuildMode buildMode = BuildMode.fromCliName(buildModeEnvironment);
    final String targetFile = environment.defines[kTargetFile] ??
        environment.fileSystem.path.join('lib', 'main.dart');
    final File packagesFile = environment.projectDir
        .childDirectory('.dart_tool')
        .childFile('package_config.json');
    final String targetFileAbsolute =
        environment.fileSystem.file(targetFile).absolute.path;
    // everything besides 'false' is considered to be enabled.
    final bool trackWidgetCreation =
        environment.defines[kTrackWidgetCreation] != 'false';

    // This configuration is all optional.
    final String? frontendServerStarterPath =
        environment.defines[kFrontendServerStarterPath];
    final List<String> extraFrontEndOptions =
        decodeCommaSeparated(environment.defines, kExtraFrontEndOptions);
    final List<String>? fileSystemRoots =
        environment.defines[kFileSystemRoots]?.split(',');
    final String? fileSystemScheme = environment.defines[kFileSystemScheme];

    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
      packagesFile,
      logger: environment.logger,
    );

    final String dillPath =
        environment.buildDir.childFile(KernelSnapshot.dillName).path;

    final CompilerOutput? output = await compiler.compile(
      sdkRoot: environment.artifacts.getArtifactPath(
        Artifact.flutterPatchedSdkPath,
        mode: buildMode,
      ),
      aot: buildMode.isPrecompiled,
      buildMode: buildMode,
      trackWidgetCreation:
          trackWidgetCreation && buildMode != BuildMode.release,
      outputFilePath: dillPath,
      initializeFromDill: buildMode.isPrecompiled ? null : dillPath,
      packagesPath: packagesFile.path,
      linkPlatformKernelIn: buildMode.isPrecompiled,
      mainPath: targetFileAbsolute,
      depFilePath:
          environment.buildDir.childFile(KernelSnapshot.depfile).path,
      frontendServerStarterPath: frontendServerStarterPath,
      extraFrontEndOptions: extraFrontEndOptions,
      fileSystemRoots: fileSystemRoots,
      fileSystemScheme: fileSystemScheme,
      dartDefines: decodeDartDefines(environment.defines, kDartDefines),
      packageConfig: packageConfig,
      buildDir: environment.buildDir,
      targetOS: 'linux',
      checkDartPluginRegistry: environment.generateDartPluginRegistry,
    );
    if (output == null || output.errorCount != 0) {
      throw Exception();
    }
  }
}

class TizenKernelSnapshot extends KernelSnapshot {
  const TizenKernelSnapshot();

  @override
  List<Target> get dependencies => const <Target>[
        TizenKernelSnapshotProgram(),
      ];
}

/// Prepares the pre-built Flutter bundle.
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
        TizenKernelSnapshot(),
      ];

  @override
  Future<void> build(Environment environment) async {
    final String? buildModeEnvironment = environment.defines[kBuildMode];
    if (buildModeEnvironment == null) {
      throw MissingDefineException(kBuildMode, name);
    }
    final BuildMode buildMode = BuildMode.fromCliName(buildModeEnvironment);
    final Directory outputDirectory = environment.buildDir
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
      buildMode: buildMode,
      flavor: environment.defines[kFlavor],
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

/// Generates an AOT snapshot (app.so) of the Dart code.
///
/// Source: [AotElfRelease] in `common.dart`
class TizenAotElf extends AotElfBase {
  TizenAotElf(this.targetPlatform, this.buildMode);

  final TargetPlatform targetPlatform;
  final BuildMode buildMode;

  @override
  String get name => 'tizen_aot_elf';

  @override
  List<Source> get inputs => <Source>[
        const Source.pattern('{BUILD_DIR}/app.dill'),
        const Source.artifact(Artifact.engineDartBinary),
        const Source.artifact(Artifact.skyEnginePath),
        Source.artifact(Artifact.genSnapshot,
            platform: targetPlatform, mode: buildMode),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.so'),
      ];

  @override
  List<Target> get dependencies => const <Target>[
        TizenKernelSnapshot(),
      ];
}

/// Source: [DebugAndroidApplication] in `android.dart`
class DebugTizenApplication extends TizenAssetBundle {
  DebugTizenApplication(this.buildInfo);

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
        const Source.pattern('{BUILD_DIR}/flutter_assets/vm_snapshot_data'),
        const Source.pattern(
            '{BUILD_DIR}/flutter_assets/isolate_snapshot_data'),
        const Source.pattern('{BUILD_DIR}/flutter_assets/kernel_blob.bin'),
      ];

  @override
  List<Target> get dependencies => <Target>[
        ...super.dependencies,
        NativePlugins(buildInfo),
      ];
}

/// See: [ReleaseAndroidApplication] in `android.dart`
class ReleaseTizenApplication extends TizenAssetBundle {
  ReleaseTizenApplication(this.buildInfo);

  final TizenBuildInfo buildInfo;

  @override
  String get name => 'release_tizen_application';

  @override
  List<Target> get dependencies => <Target>[
        ...super.dependencies,
        TizenAotElf(getTargetPlatformForArch(buildInfo.targetArch),
            buildInfo.buildInfo.mode),
        NativePlugins(buildInfo),
      ];
}
