// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/build_targets/application.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/compile.dart';
import 'package:flutter_tools/src/features.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fake_process_manager.dart';
import '../../src/fakes.dart';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late Logger logger;
  late Artifacts artifacts;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();
    logger = BufferLogger.test();
    artifacts = Artifacts.test();
  });

  testUsingContext('Debug bundle contains expected resources', () async {
    final environment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{kBuildMode: 'debug'},
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );
    environment.buildDir.childFile('app.dill').createSync(recursive: true);
    environment.buildDir.childFile('native_assets.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    fileSystem
        .file(artifacts.getArtifactPath(Artifact.vmSnapshotData, mode: BuildMode.debug))
        .createSync(recursive: true);
    fileSystem
        .file(artifacts.getArtifactPath(Artifact.isolateSnapshotData, mode: BuildMode.debug))
        .createSync(recursive: true);

    await DebugTizenApplication(const TizenBuildInfo(
      BuildInfo.debug,
      targetArch: 'arm',
      deviceProfile: 'common',
    )).build(environment);

    final Directory bundleDir = environment.buildDir.childDirectory('flutter_assets');
    expect(bundleDir.childFile('vm_snapshot_data'), exists);
    expect(bundleDir.childFile('isolate_snapshot_data'), exists);
    expect(bundleDir.childFile('kernel_blob.bin'), exists);
    expect(bundleDir.childFile('NativeAssetsManifest.json'), exists);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
  });

  testUsingContext('TizenKernelSnapshotProgram passes --recorded-uses on release builds', () async {
    final environment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{kBuildMode: 'release'},
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );
    fileSystem.file('.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"configVersion": 2, "packages":[]}');
    final String build = environment.buildDir.path;
    processManager.addCommand(FakeCommand(
      command: <String>[
        artifacts.getArtifactPath(Artifact.engineDartAotRuntime),
        artifacts.getArtifactPath(Artifact.frontendServerSnapshotForEngineDartSdk),
        '--sdk-root',
        '${artifacts.getArtifactPath(Artifact.flutterPatchedSdkPath, mode: BuildMode.release)}/',
        '--target=flutter',
        '--no-print-incremental-dependencies',
        ...buildModeOptions(BuildMode.release, <String>[]),
        '--aot',
        '--tfa',
        '--target-os',
        'linux',
        '--packages',
        '/.dart_tool/package_config.json',
        '--output-dill',
        '$build/app.dill',
        '--depfile',
        '$build/kernel_snapshot_program.d',
        '--verbosity=error',
        '--recorded-uses=$build/recorded_uses.json',
        'file:///lib/main.dart',
      ],
      stdout: 'result abc\nabc\nabc $build/app.dill 0\n',
    ));

    await const TizenKernelSnapshotProgram().build(environment);

    expect(processManager, hasNoRemainingExpectations);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    FeatureFlags: () => TestFeatureFlags(isRecordUseEnabled: true),
  });

  testUsingContext('TizenKernelSnapshotProgram writes empty recorded uses on debug builds',
      () async {
    final environment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{kBuildMode: 'debug'},
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );
    environment.buildDir.createSync(recursive: true);
    fileSystem.file('.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"configVersion": 2, "packages":[]}');

    final String build = environment.buildDir.path;
    processManager.addCommand(FakeCommand(
      command: <String>[
        artifacts.getArtifactPath(Artifact.engineDartAotRuntime),
        artifacts.getArtifactPath(Artifact.frontendServerSnapshotForEngineDartSdk),
        '--sdk-root',
        '${artifacts.getArtifactPath(Artifact.flutterPatchedSdkPath, mode: BuildMode.debug)}/',
        '--target=flutter',
        '--no-print-incremental-dependencies',
        ...buildModeOptions(BuildMode.debug, <String>[]),
        '--track-widget-creation',
        '--no-link-platform',
        '--packages',
        '/.dart_tool/package_config.json',
        '--output-dill',
        '$build/app.dill',
        '--depfile',
        '$build/kernel_snapshot_program.d',
        '--incremental',
        '--initialize-from-dill',
        '$build/app.dill',
        '--verbosity=error',
        'file:///lib/main.dart',
      ],
      stdout: 'result abc\nabc\nabc $build/app.dill 0\n',
    ));

    await const TizenKernelSnapshotProgram().build(environment);

    expect(processManager, hasNoRemainingExpectations);
    expect(environment.buildDir.childFile('recorded_uses.json').readAsStringSync(), '{}');
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    FeatureFlags: () => TestFeatureFlags(isRecordUseEnabled: true),
  });

  testUsingContext('TizenAotElf renames app.android-arm.symbols to app.tizen-arm.symbols',
      () async {
    final environment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{
        kBuildMode: 'release',
        kTargetPlatform: 'android-arm',
        kSplitDebugInfo: 'debug_info',
      },
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: FakeProcessManager.any(),
    );

    final Directory splitDebugInfoDir = fileSystem.directory('debug_info');
    splitDebugInfoDir.childFile('app.android-arm.symbols').createSync(recursive: true);

    await TizenAotElf(TargetPlatform.android_arm, BuildMode.release).build(environment);

    expect(splitDebugInfoDir.childFile('app.tizen-arm.symbols'), exists);
    expect(splitDebugInfoDir.childFile('app.android-arm.symbols'), isNot(exists));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
  });
}
