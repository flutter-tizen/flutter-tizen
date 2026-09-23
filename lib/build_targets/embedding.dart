// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/project.dart';

import '../tizen_build_info.dart';
import '../tizen_project.dart';
import '../tizen_sdk.dart';
import '../tizen_tpk.dart';
import 'utils.dart';

class NativeEmbedding extends Target {
  NativeEmbedding(this.buildInfo);

  final TizenBuildInfo buildInfo;

  @override
  String get name => 'tizen_cpp_embedding';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{FLUTTER_ROOT}/../lib/build_targets/embedding.dart'),
        Source.pattern('{FLUTTER_ROOT}/../lib/build_targets/utils.dart'),
        Source.pattern('{FLUTTER_ROOT}/../lib/tizen_sdk.dart'),
      ];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  List<String> get depfiles => <String>[
        'tizen_embedding.d',
      ];

  @override
  List<Target> get dependencies => const <Target>[];

  @override
  Future<void> build(Environment environment) async {
    final inputs = <File>[];
    final outputs = <File>[];
    final depfileService = DepfileService(
      fileSystem: environment.fileSystem,
      logger: environment.logger,
    );

    final FlutterProject project = FlutterProject.fromDirectory(environment.projectDir);
    final tizenProject = TizenProject.fromFlutter(project);

    final Directory outputDir = environment.buildDir.childDirectory('tizen_embedding')
      ..createSync(recursive: true);
    final Directory embeddingDir = environment.fileSystem
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('embedding')
        .childDirectory('cpp');
    embeddingDir.listSync().whereType<File>().forEach(inputs.add);
    copyDirectory(
      embeddingDir.childDirectory('include'),
      outputDir.childDirectory('include'),
      onFileCopied: (File srcFile, File destFile) {
        inputs.add(srcFile);
        outputs.add(destFile);
      },
    );

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final String buildConfig = getBuildConfig(buildMode);

    final Directory commonDir = getCommonArtifactsDirectory();
    final Directory clientWrapperDir = commonDir.childDirectory('cpp_client_wrapper');
    final Directory publicDir = commonDir.childDirectory('public');
    clientWrapperDir.listSync(recursive: true).whereType<File>().forEach(inputs.add);
    publicDir.listSync(recursive: true).whereType<File>().forEach(inputs.add);

    getDartSdkDirectory()
        .childDirectory('include')
        .listSync(recursive: true)
        .whereType<File>()
        .forEach(inputs.add);

    assert(tizenSdk != null);
    String? apiVersion;
    if (tizenProject.manifestFile.existsSync()) {
      final TizenManifest tizenManifest = TizenManifest.parseFromXml(tizenProject.manifestFile);
      apiVersion = tizenManifest.apiVersion;
      inputs.add(tizenProject.manifestFile);
    }
    final Rootstrap rootstrap = tizenSdk!.getRootstrap(
      profile: buildInfo.deviceProfile,
      apiVersion: apiVersion,
      arch: buildInfo.targetArch,
    );

    // Build in a copy laid out like this repository, which project_def.prop
    // refers to, so that concurrent builds never share the build directory
    // or the objects of ../../flutter/**/*.cc.
    final Directory workDir = environment.buildDir.childDirectory('tizen_embedding_build');
    if (workDir.existsSync()) {
      workDir.deleteSync(recursive: true);
    }
    final Directory sourceDir = workDir.childDirectory('embedding').childDirectory('cpp');
    copyDirectory(
      embeddingDir,
      sourceDir,
      shouldCopyDirectory: (Directory dir) =>
          !<String>{'Debug', 'Release', 'runner'}.contains(dir.basename),
    );
    final Directory cacheDir =
        workDir.childDirectory('flutter').childDirectory('bin').childDirectory('cache');
    final Directory workCommonDir = cacheDir
        .childDirectory('artifacts')
        .childDirectory('engine')
        .childDirectory('tizen-common');
    copyDirectory(clientWrapperDir, workCommonDir.childDirectory('cpp_client_wrapper'));
    copyDirectory(publicDir, workCommonDir.childDirectory('public'));
    copyDirectory(
      getDartSdkDirectory().childDirectory('include'),
      cacheDir.childDirectory('dart-sdk').childDirectory('include'),
    );

    final Directory buildDir = sourceDir.childDirectory(buildConfig);
    final RunResult result = await tizenSdk!.buildNative(
      sourceDir.path,
      configuration: buildConfig,
      arch: getTizenCliArch(buildInfo.targetArch),
      predefines: <String>[
        '${buildInfo.deviceProfile.toUpperCase()}_PROFILE',
        if (usesTizenCoreEmbedder(apiVersion)) 'TIZEN_CORE',
      ],
      extraOptions: <String>['-fPIC'],
      rootstrap: rootstrap.id,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to build C++ embedding:\n$result');
    }

    final File outputLib = buildDir.childFile('libembedding_cpp.a');
    if (!outputLib.existsSync()) {
      throwToolExit(
        'Build succeeded but the file ${outputLib.path} is not found:\n'
        '${result.stdout}',
      );
    }
    outputs.add(outputLib.copySync(outputDir.childFile(outputLib.basename).path));
    workDir.deleteSync(recursive: true);

    depfileService.writeToFile(
      Depfile(inputs, outputs),
      environment.buildDir.childFile('tizen_embedding.d'),
    );
  }
}
