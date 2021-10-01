// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/project.dart';

import '../tizen_build_info.dart';
import '../tizen_project.dart';
import '../tizen_sdk.dart';
import '../tizen_tpk.dart';
import 'utils.dart';

class DotnetTpk {
  DotnetTpk(this.buildInfo);

  final TizenBuildInfo buildInfo;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  Future<void> build(Environment environment) async {
    final FlutterProject project =
        FlutterProject.fromDirectory(environment.projectDir);
    final TizenProject tizenProject = TizenProject.fromFlutter(project);

    // Clean up the intermediate and output directories.
    final Directory ephemeralDir = tizenProject.ephemeralDirectory;
    if (ephemeralDir.existsSync()) {
      ephemeralDir.deleteSync(recursive: true);
    }
    final Directory resDir = ephemeralDir.childDirectory('res')
      ..createSync(recursive: true);
    final Directory libDir = ephemeralDir.childDirectory('lib')
      ..createSync(recursive: true);

    final Directory outputDir = environment.outputDir.childDirectory('tpk');
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);

    // Copy necessary files.
    final Directory flutterAssetsDir = resDir.childDirectory('flutter_assets');
    copyDirectory(
      environment.outputDir.childDirectory('flutter_assets'),
      flutterAssetsDir,
    );

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final Directory engineDir =
        getEngineArtifactsDirectory(buildInfo.targetArch, buildMode);
    final Directory commonDir = engineDir.parent.childDirectory('tizen-common');

    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedder =
        engineDir.childFile('libflutter_tizen_${buildInfo.deviceProfile}.so');
    final File icuData =
        commonDir.childDirectory('icu').childFile('icudtl.dat');

    engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
    // The embedder so name is statically defined in C# code and cannot be
    // provided at runtime, so the file name must be a constant.
    embedder.copySync(libDir.childFile('libflutter_tizen.so').path);
    icuData.copySync(resDir.childFile(icuData.basename).path);

    if (buildMode.isPrecompiled) {
      final File aotSharedLib = environment.buildDir.childFile('app.so');
      aotSharedLib.copySync(libDir.childFile('libapp.so').path);
    }

    final Directory pluginsDir =
        environment.buildDir.childDirectory('tizen_plugins');
    final File pluginsLib = pluginsDir.childFile('libflutter_plugins.so');
    if (pluginsLib.existsSync()) {
      pluginsLib.copySync(libDir.childFile(pluginsLib.basename).path);
    }
    final Directory pluginsUserLibDir = pluginsDir.childDirectory('lib');
    if (pluginsUserLibDir.existsSync()) {
      pluginsUserLibDir.listSync().whereType<File>().forEach(
          (File lib) => lib.copySync(libDir.childFile(lib.basename).path));
    }

    // Run the .NET build.
    if (dotnetCli == null) {
      throwToolExit(
        'Unable to locate .NET CLI executable.\n'
        'Install the latest .NET SDK from: https://dotnet.microsoft.com/download',
      );
    }
    final RunResult result = await _processUtils.run(<String>[
      dotnetCli!.path,
      'build',
      '-c',
      if (buildMode.isPrecompiled) 'Release' else 'Debug',
      '-o',
      '${outputDir.path}/', // The trailing '/' is needed.
      tizenProject.editableDirectory.path,
    ]);
    if (result.exitCode != 0) {
      throwToolExit('Failed to build .NET application:\n$result');
    }

    final File outputTpk = outputDir.childFile(tizenProject.outputTpkName);
    if (!outputTpk.existsSync()) {
      throwToolExit(
          'Build succeeded but the expected TPK not found:\n${result.stdout}');
    }

    assert(tizenSdk != null);
    // build-task-tizen signs the output TPK with a dummy profile by default.
    // We need to re-generate the TPK by signing with a correct profile.
    String? securityProfile = buildInfo.securityProfile;
    final SecurityProfiles? securityProfiles = tizenSdk!.securityProfiles;
    if (securityProfile != null) {
      if (securityProfiles == null ||
          !securityProfiles.contains(securityProfile)) {
        throwToolExit('The profile $securityProfile does not exist.');
      }
    }
    if (securityProfile == null && securityProfiles != null) {
      securityProfile = securityProfiles.active;
    }
    if (securityProfile != null) {
      environment.logger
          .printStatus('The $securityProfile profile is used for signing.');
      final RunResult result =
          await tizenSdk!.package(outputTpk.path, sign: securityProfile);
      if (result.exitCode != 0) {
        throwToolExit('Failed to sign the TPK:\n$result');
      }
    } else {
      environment.logger.printStatus(
        'The TPK was signed with a default certificate. You can create one using Certificate Manager.\n'
        'https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/install-tizen-sdk.md#create-a-tizen-certificate',
      );
    }
  }
}

class NativeTpk {
  NativeTpk(this.buildInfo);

  final TizenBuildInfo buildInfo;

  Future<void> build(Environment environment) async {
    final FlutterProject project =
        FlutterProject.fromDirectory(environment.projectDir);
    final TizenProject tizenProject = TizenProject.fromFlutter(project);

    // Clean up the intermediate and output directories.
    final Directory tizenDir = tizenProject.editableDirectory;
    final Directory projectDir =
        tizenProject.isMultiApp ? tizenProject.uiAppDirectory : tizenDir;
    final Directory resDir = projectDir.childDirectory('res');
    if (resDir.existsSync()) {
      resDir.deleteSync(recursive: true);
    }
    resDir.createSync(recursive: true);
    final Directory libDir = projectDir.childDirectory('lib');
    if (libDir.existsSync()) {
      libDir.deleteSync(recursive: true);
    }
    libDir.createSync(recursive: true);

    final Directory outputDir = environment.outputDir.childDirectory('tpk');
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);

    // Copy necessary files.
    final Directory flutterAssetsDir = resDir.childDirectory('flutter_assets');
    copyDirectory(
      environment.outputDir.childDirectory('flutter_assets'),
      flutterAssetsDir,
    );

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final String buildConfig = buildMode.isPrecompiled ? 'Release' : 'Debug';
    final Directory engineDir =
        getEngineArtifactsDirectory(buildInfo.targetArch, buildMode);
    final Directory commonDir = engineDir.parent.childDirectory('tizen-common');

    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedder =
        engineDir.childFile('libflutter_tizen_${buildInfo.deviceProfile}.so');
    final File icuData =
        commonDir.childDirectory('icu').childFile('icudtl.dat');

    engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
    embedder.copySync(libDir.childFile(embedder.basename).path);
    icuData.copySync(resDir.childFile(icuData.basename).path);

    if (buildMode.isPrecompiled) {
      final File aotSharedLib = environment.buildDir.childFile('app.so');
      aotSharedLib.copySync(libDir.childFile('libapp.so').path);
    }

    final Directory pluginsDir =
        environment.buildDir.childDirectory('tizen_plugins');
    final File pluginsLib = pluginsDir.childFile('libflutter_plugins.so');
    if (pluginsLib.existsSync()) {
      pluginsLib.copySync(libDir.childFile(pluginsLib.basename).path);
    }
    final Directory pluginsUserLibDir = pluginsDir.childDirectory('lib');
    if (pluginsUserLibDir.existsSync()) {
      pluginsUserLibDir.listSync().whereType<File>().forEach(
          (File lib) => lib.copySync(libDir.childFile(lib.basename).path));
    }

    // Prepare for build.
    final Directory clientWrapperDir =
        commonDir.childDirectory('cpp_client_wrapper');
    final Directory publicDir = commonDir.childDirectory('public');
    final Directory embeddingDir = environment.fileSystem
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('embedding')
        .childDirectory('cpp');

    assert(tizenSdk != null);
    final TizenManifest tizenManifest =
        TizenManifest.parseFromXml(tizenProject.manifestFile);
    final Rootstrap rootstrap = tizenSdk!.getFlutterRootstrap(
      profile: tizenManifest.profile,
      apiVersion: tizenManifest.apiVersion,
      arch: buildInfo.targetArch,
    );

    // We need to build the C++ embedding separately because the absolute path
    // to the embedding directory may contain spaces.
    RunResult result = await tizenSdk!.buildNative(
      embeddingDir.path,
      configuration: buildConfig,
      arch: getTizenCliArch(buildInfo.targetArch),
      extraOptions: <String>['-fPIC'],
      rootstrap: rootstrap.id,
    );
    final File embeddingLib = embeddingDir
        .childDirectory(buildConfig)
        .childFile('libembedding_cpp.a');
    if (result.exitCode != 0) {
      throwToolExit('Failed to build ${embeddingLib.basename}:\n$result');
    }
    const List<String> embeddingDependencies = <String>[
      'appcore-agent',
      'capi-appfw-app-common',
      'capi-appfw-application',
      'dlog',
    ];

    final Directory buildDir = projectDir.childDirectory(buildConfig);
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }
    buildDir.createSync(recursive: true);

    // The output TPK is signed with an active profile unless otherwise
    // specified.
    String? securityProfile = buildInfo.securityProfile;
    final SecurityProfiles? securityProfiles = tizenSdk!.securityProfiles;
    if (securityProfile != null) {
      if (securityProfiles == null ||
          !securityProfiles.contains(securityProfile)) {
        throwToolExit('The profile $securityProfile does not exist.');
      }
    }
    if (securityProfile == null && securityProfiles != null) {
      securityProfile = securityProfiles.active;
    }
    if (securityProfile != null) {
      environment.logger
          .printStatus('The $securityProfile profile is used for signing.');
    } else {
      throwToolExit(
        'Native TPKs cannot be built without valid certificates. You can create one using Certificate Manager.\n'
        'https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/install-tizen-sdk.md#create-a-tizen-certificate',
      );
    }

    final List<String> extraOptions = <String>[
      // The extra quotation marks ("") for linker flags are required due to
      // https://github.com/flutter-tizen/flutter-tizen/issues/218.
      '"-Wl,--unresolved-symbols=ignore-in-shared-libs"',
      '-lflutter_tizen_${buildInfo.deviceProfile}',
      '-L${libDir.path.toPosixPath()}',
      '-I${clientWrapperDir.childDirectory('include').path.toPosixPath()}',
      '-I${publicDir.path.toPosixPath()}',
      '-I${embeddingDir.childDirectory('include').path.toPosixPath()}',
      '"-Wl,--whole-archive"',
      embeddingLib.path.toPosixPath(),
      '"-Wl,--no-whole-archive"',
      for (String lib in embeddingDependencies) '-l$lib',
      '-I${pluginsDir.childDirectory('include').path.toPosixPath()}',
      if (pluginsLib.existsSync()) '-lflutter_plugins',
    ];

    // Build the app.
    result = await tizenSdk!.buildApp(
      tizenDir.path,
      build: <String, Object>{
        'name': 'b1',
        'methods': <String>['m1'],
        'targets':
            tizenProject.isMultiApp ? <String>['ui', 'service'] : <String>['.'],
      },
      method: <String, Object>{
        'name': 'm1',
        'configs': <String>[buildConfig],
        'compiler': tizenSdk!.defaultNativeCompiler,
        'predefines': <String>[
          '${buildInfo.deviceProfile.toUpperCase()}_PROFILE',
        ],
        'extraoption': extraOptions.join(' '),
        'rootstraps': <Map<String, String>>[
          <String, String>{
            'name': rootstrap.id,
            'arch': getTizenCliArch(buildInfo.targetArch),
          },
        ],
      },
      output: buildDir.path,
      package: <String, Object>{
        'name': tizenManifest.packageId,
        'targets': <String>['b1'],
      },
      sign: securityProfile,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to build native application:\n$result');
    }

    File? outputTpk;
    for (final File file in buildDir.listSync().whereType<File>()) {
      if (file.basename.endsWith('.tpk')) {
        outputTpk = file;
        break;
      }
    }
    if (outputTpk == null) {
      throwToolExit('Build succeeded but the expected TPK not found:\n$result');
    }
    // Copy and rename the output TPK.
    outputTpk.copySync(outputDir.childFile(tizenProject.outputTpkName).path);

    // Extract the contents of the TPK to support code size analysis.
    final Directory tpkrootDir = outputDir.childDirectory('tpkroot');
    globals.os.unzip(outputTpk, tpkrootDir);
  }
}
