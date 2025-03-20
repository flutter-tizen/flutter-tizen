// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:meta/meta.dart';

import '../tizen_build_info.dart';
import '../tizen_project.dart';
import '../tizen_sdk.dart';
import '../tizen_tpk.dart';
import 'application.dart';
import 'embedding.dart';
import 'utils.dart';

/// This target doesn't specify any input or output but the build system always
/// triggers [build] without skipping.
/// This doesn't affect subsequent builds of [dependencies].
///
/// See: [Node.missingDepfile] in `build_system.dart`
abstract class TizenPackage extends Target {
  const TizenPackage(this.buildInfo);

  final TizenBuildInfo buildInfo;

  @nonVirtual
  @override
  List<Source> get inputs => const <Source>[];

  @nonVirtual
  @override
  List<Source> get outputs => const <Source>[];

  @nonVirtual
  @override
  List<String> get depfiles => const <String>[
        // This makes this target unskippable.
        'non_existent_file',
      ];

  @override
  List<Target> get dependencies => <Target>[
        if (buildInfo.buildInfo.isDebug)
          DebugTizenApplication(buildInfo)
        else
          ReleaseTizenApplication(buildInfo),
      ];
}

class DotnetTpk extends TizenPackage {
  DotnetTpk(super.tizenBuildInfo);

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  @override
  String get name => 'tizen_dotnet_tpk';

  @override
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

    final Directory outputDir = environment.outputDir;
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);

    // Copy necessary files.
    copyDirectory(
      environment.buildDir.childDirectory('flutter_assets'),
      resDir.childDirectory('flutter_assets'),
    );

    final TizenManifest tizenManifest =
        TizenManifest.parseFromXml(tizenProject.manifestFile);
    final String profile = buildInfo.deviceProfile;
    final String? apiVersion = tizenManifest.apiVersion;

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final String buildConfig = getBuildConfig(buildMode);

    final Directory engineDir =
        getEngineArtifactsDirectory(buildInfo.targetArch, buildMode);
    final Directory embedderDir =
        getEmbedderArtifactsDirectory(apiVersion, buildInfo.targetArch);
    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedder = embedderDir.childFile('libflutter_tizen_$profile.so');
    final File icuData = engineDir.childFile('icudtl.dat');
    final File appDepsJson = project.directory.childFile('app.deps.json');

    engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
    // The embedder so name is statically defined in C# code and cannot be
    // provided at runtime, so the file name must be a constant.
    embedder.copySync(libDir.childFile('libflutter_tizen.so').path);
    icuData.copySync(resDir.childFile(icuData.basename).path);
    appDepsJson.copySync(
        tizenProject.hostAppRoot.childFile(appDepsJson.basename).path);

    if (buildMode.isPrecompiled) {
      final File aotSnapshot = environment.buildDir.childFile('app.so');
      aotSnapshot.copySync(libDir.childFile('libapp.so').path);
    }

    final Directory pluginsDir =
        environment.buildDir.childDirectory('tizen_plugins');
    final Directory pluginsResDir = pluginsDir.childDirectory('res');
    if (pluginsResDir.existsSync()) {
      copyDirectory(pluginsResDir, resDir);
    }
    final Directory pluginsLibDir = pluginsDir.childDirectory('lib');
    if (pluginsLibDir.existsSync()) {
      copyDirectory(pluginsLibDir, libDir);
    }

    assert(tizenSdk != null);
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
        'No certificate profile found. You can create one using the Certificate Manager.\n'
        'https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/install-tizen-sdk.md#create-a-tizen-certificate',
      );
    }

    File locateTpk(String stdout) {
      // "Runner -> /path/to/project/tizen/bin/Debug/tizen80/com.example.app-1.0.0.tpk"
      final Match? match = RegExp(' -> (.+.tpk)').firstMatch(stdout);
      if (match == null) {
        throwToolExit('Unable to locate the output TPK:\n$stdout');
      }
      final File tpkFile = environment.fileSystem.file(match.group(1));
      if (!tpkFile.existsSync()) {
        throwToolExit(
            'Build succeeded but the expected TPK not found:\n$stdout');
      }
      return tpkFile;
    }

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
      buildConfig,
      '/p:DefineConstants=${profile.toUpperCase()}_PROFILE',
      tizenProject.hostAppRoot.path,
    ]);
    if (result.exitCode != 0) {
      throwToolExit('Failed to build .NET application:\n$result');
    }
    final File outputTpk = locateTpk(result.stdout);

    if (tizenProject.isMultiApp) {
      // Build the service app.
      RunResult result = await _processUtils.run(<String>[
        dotnetCli!.path,
        'build',
        '-c',
        buildConfig,
        '/p:DefineConstants=${profile.toUpperCase()}_PROFILE',
        tizenProject.serviceAppDirectory.path,
      ]);
      if (result.exitCode != 0) {
        throwToolExit('Failed to build .NET service application:\n$result');
      }
      final File serviceOutputTpk = locateTpk(result.stdout);

      // Merge two TPKs into a single package.
      result = await tizenSdk!.package(
        outputTpk.path,
        reference: serviceOutputTpk.path,
        sign: securityProfile,
      );
      if (result.exitCode != 0) {
        throwToolExit('Failed to create a TPK:\n$result');
      }
    } else {
      // build-task-tizen signs the output TPK with a dummy profile by default.
      // We need to regenerate the TPK by signing it with a valid profile.
      final RunResult result =
          await tizenSdk!.package(outputTpk.path, sign: securityProfile);
      if (result.exitCode != 0) {
        throwToolExit('Failed to sign the TPK:\n$result');
      }
    }

    // Copy the TPK and tpkroot to the output directory.
    outputTpk.copySync(outputDir.childFile(tizenProject.outputTpkName).path);
    final Directory tpkrootDir = outputTpk.parent.childDirectory('tpkroot');
    if (tpkrootDir.existsSync()) {
      copyDirectory(tpkrootDir, outputDir.childDirectory('tpkroot'));
    }
  }
}

class NativeTpk extends TizenPackage {
  NativeTpk(super.tizenBuildInfo);

  @override
  String get name => 'tizen_native_tpk';

  @override
  List<Target> get dependencies => <Target>[
        ...super.dependencies,
        NativeEmbedding(buildInfo),
      ];

  @override
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

    final Directory outputDir = environment.outputDir;
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);

    // Copy necessary files.
    copyDirectory(
      environment.buildDir.childDirectory('flutter_assets'),
      resDir.childDirectory('flutter_assets'),
    );

    final TizenManifest tizenManifest =
        TizenManifest.parseFromXml(tizenProject.manifestFile);
    final String profile = buildInfo.deviceProfile;
    final String? apiVersion = tizenManifest.apiVersion;

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final String buildConfig = getBuildConfig(buildMode);

    final Directory engineDir =
        getEngineArtifactsDirectory(buildInfo.targetArch, buildMode);
    final Directory embedderDir =
        getEmbedderArtifactsDirectory(apiVersion, buildInfo.targetArch);

    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedder = embedderDir.childFile('libflutter_tizen_$profile.so');
    final File icuData = engineDir.childFile('icudtl.dat');
    final File appDepsJson = project.directory.childFile('app.deps.json');

    engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
    embedder.copySync(libDir.childFile(embedder.basename).path);
    icuData.copySync(resDir.childFile(icuData.basename).path);
    appDepsJson.copySync(
        tizenProject.hostAppRoot.childFile(appDepsJson.basename).path);

    if (buildMode.isPrecompiled) {
      final File aotSnapshot = environment.buildDir.childFile('app.so');
      aotSnapshot.copySync(libDir.childFile('libapp.so').path);
    }

    final Directory pluginsDir =
        environment.buildDir.childDirectory('tizen_plugins');
    final Directory pluginsResDir = pluginsDir.childDirectory('res');
    if (pluginsResDir.existsSync()) {
      copyDirectory(pluginsResDir, resDir);
    }
    final Directory pluginsLibDir = pluginsDir.childDirectory('lib');
    final List<String> pluginLibs = <String>[];
    if (pluginsLibDir.existsSync()) {
      copyDirectory(
        pluginsLibDir,
        libDir,
        onFileCopied: (File srcFile, File destFile) {
          pluginLibs.add(getLibNameForFileName(srcFile.basename));
        },
      );
    }

    // Prepare for build.
    final Directory commonDir = getCommonArtifactsDirectory();
    final Directory clientWrapperDir =
        commonDir.childDirectory('cpp_client_wrapper');
    final Directory publicDir = commonDir.childDirectory('public');

    final Directory dartSdkDir = getDartSdkDirectory();

    assert(tizenSdk != null);
    final Rootstrap rootstrap = tizenSdk!.getRootstrap(
      profile: profile,
      apiVersion: tizenManifest.apiVersion,
      arch: buildInfo.targetArch,
    );

    final Directory embeddingDir =
        environment.buildDir.childDirectory('tizen_embedding');
    final File embeddingLib = embeddingDir.childFile('libembedding_cpp.a');
    const List<String> embeddingDependencies = <String>[
      'appcore-agent',
      'capi-appfw-app-common',
      'capi-appfw-application',
      'capi-appfw-app-manager',
      'dlog',
      'elementary',
      'evas',
    ];

    final Directory buildDir =
        tizenProject.hostAppRoot.childDirectory(buildConfig);
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }
    buildDir.createSync(recursive: true);

    if (tizenProject.isMultiApp) {
      final Directory serviceBuildDir =
          tizenProject.serviceAppDirectory.childDirectory(buildConfig);
      if (serviceBuildDir.existsSync()) {
        serviceBuildDir.deleteSync(recursive: true);
      }
      serviceBuildDir.createSync(recursive: true);
    }

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
        'No certificate profile found. You can create one using the Certificate Manager.\n'
        'https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/install-tizen-sdk.md#create-a-tizen-certificate',
      );
    }

    final List<String> extraOptions = <String>[
      // The extra quotation marks ("") for linker flags are required due to
      // https://github.com/flutter-tizen/flutter-tizen/issues/218.
      '"-Wl,--unresolved-symbols=ignore-in-shared-libs"',
      '-I${clientWrapperDir.childDirectory('include').path.toPosixPath()}',
      '-I${publicDir.path.toPosixPath()}',
      '-I${dartSdkDir.childDirectory('include').path.toPosixPath()}',
      '-I${embeddingDir.childDirectory('include').path.toPosixPath()}',
      embeddingLib.path.toPosixPath(),
      '-L${libDir.path.toPosixPath()}',
      '-lflutter_tizen_$profile',
      for (final String lib in embeddingDependencies) '-l$lib',
      '-I${tizenProject.managedDirectory.path.toPosixPath()}',
      '-I${pluginsDir.childDirectory('include').path.toPosixPath()}',
      for (final String lib in pluginLibs) '-l$lib',
    ];

    // Build the app.
    RunResult result = await tizenSdk!.buildApp(
      tizenProject.editableDirectory.path,
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
          '${profile.toUpperCase()}_PROFILE',
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
      environment: <String, String>{
        'FLUTTER_BUILD_DIR': environment.buildDir.path.toPosixPath(''),
        'API_VERSION': apiVersion ?? '',
      },
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

    // Add files from the intermediate directory and sign the TPK.
    result = await tizenSdk!.package(
      outputTpk.path,
      extraDir: ephemeralDir.path,
      sign: securityProfile,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to sign the TPK:\n$result');
    }

    // Copy and rename the output TPK.
    outputTpk.copySync(outputDir.childFile(tizenProject.outputTpkName).path);

    // Extract the contents of the TPK to support code size analysis.
    final Directory tpkrootDir = outputDir.childDirectory('tpkroot');
    globals.os.unzip(outputTpk, tpkrootDir);
  }
}

class DotnetModule extends TizenPackage {
  DotnetModule(super.tizenBuildInfo);

  @override
  String get name => 'tizen_dotnet_module';

  @override
  Future<void> build(Environment environment) async {
    final FlutterProject project =
        FlutterProject.fromDirectory(environment.projectDir);
    final TizenProject tizenProject = TizenProject.fromFlutter(project);

    final Directory outputDir = environment.outputDir;
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);
    final Directory resDir = outputDir.childDirectory('res')
      ..createSync(recursive: true);
    final Directory libDir = outputDir.childDirectory('lib')
      ..createSync(recursive: true);
    final Directory srcDir = outputDir.childDirectory('src')
      ..createSync(recursive: true);

    // Copy necessary files.
    copyDirectory(
      environment.buildDir.childDirectory('flutter_assets'),
      resDir.childDirectory('flutter_assets'),
    );

    final TizenManifest tizenManifest =
        TizenManifest.parseFromXml(tizenProject.manifestFile);
    final String profile = buildInfo.deviceProfile;
    final String? apiVersion = tizenManifest.apiVersion;

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final Directory engineDir =
        getEngineArtifactsDirectory(buildInfo.targetArch, buildMode);
    final Directory embedderDir =
        getEmbedderArtifactsDirectory(apiVersion, buildInfo.targetArch);

    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedder = embedderDir.childFile('libflutter_tizen_$profile.so');
    final File icuData = engineDir.childFile('icudtl.dat');

    engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
    // The embedder so name is statically defined in C# code and cannot be
    // provided at runtime, so the file name must be a constant.
    embedder.copySync(libDir.childFile('libflutter_tizen.so').path);
    icuData.copySync(resDir.childFile(icuData.basename).path);

    if (buildMode.isPrecompiled) {
      final File aotSnapshot = environment.buildDir.childFile('app.so');
      aotSnapshot.copySync(libDir.childFile('libapp.so').path);
    }

    final File generatedPluginRegistrant =
        tizenProject.managedDirectory.childFile('GeneratedPluginRegistrant.cs');
    assert(generatedPluginRegistrant.existsSync());
    generatedPluginRegistrant
        .copySync(srcDir.childFile(generatedPluginRegistrant.basename).path);

    final Directory pluginsDir =
        environment.buildDir.childDirectory('tizen_plugins');
    final Directory pluginsResDir = pluginsDir.childDirectory('res');
    if (pluginsResDir.existsSync()) {
      copyDirectory(pluginsResDir, resDir);
    }
    final Directory pluginsLibDir = pluginsDir.childDirectory('lib');
    if (pluginsLibDir.existsSync()) {
      copyDirectory(pluginsLibDir, libDir);
    }
  }
}

class NativeModule extends TizenPackage {
  NativeModule(super.tizenBuildInfo);

  @override
  String get name => 'tizen_native_module';

  @override
  List<Target> get dependencies => <Target>[
        ...super.dependencies,
        NativeEmbedding(buildInfo),
      ];

  @override
  Future<void> build(Environment environment) async {
    final FlutterProject project =
        FlutterProject.fromDirectory(environment.projectDir);
    final TizenProject tizenProject = TizenProject.fromFlutter(project);

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final String buildConfig = getBuildConfig(buildMode);

    final Directory outputDir = environment.outputDir;
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);
    final Directory incDir = outputDir.childDirectory('inc')
      ..createSync(recursive: true);
    final Directory resDir = outputDir.childDirectory('res')
      ..createSync(recursive: true);
    final Directory libDir = outputDir.childDirectory('lib')
      ..createSync(recursive: true);
    final Directory buildDir = outputDir.childDirectory(buildConfig)
      ..createSync(recursive: true);

    // Copy necessary files.
    copyDirectory(
      environment.buildDir.childDirectory('flutter_assets'),
      resDir.childDirectory('flutter_assets'),
    );

    final TizenManifest tizenManifest =
        TizenManifest.parseFromXml(tizenProject.manifestFile);
    final String profile = buildInfo.deviceProfile;
    final String? apiVersion = tizenManifest.apiVersion;

    final Directory engineDir =
        getEngineArtifactsDirectory(buildInfo.targetArch, buildMode);
    final Directory embedderDir =
        getEmbedderArtifactsDirectory(apiVersion, buildInfo.targetArch);

    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedder = embedderDir.childFile('libflutter_tizen_$profile.so');
    final File icuData = engineDir.childFile('icudtl.dat');

    engineBinary.copySync(libDir.childFile(engineBinary.basename).path);
    embedder.copySync(libDir.childFile(embedder.basename).path);
    icuData.copySync(resDir.childFile(icuData.basename).path);

    if (buildMode.isPrecompiled) {
      final File aotSnapshot = environment.buildDir.childFile('app.so');
      aotSnapshot.copySync(libDir.childFile('libapp.so').path);
    }

    final File generatedPluginRegistrant = tizenProject.managedDirectory
        .childFile('generated_plugin_registrant.h');
    assert(generatedPluginRegistrant.existsSync());
    generatedPluginRegistrant
        .copySync(incDir.childFile(generatedPluginRegistrant.basename).path);

    final Directory pluginsDir =
        environment.buildDir.childDirectory('tizen_plugins');
    final Directory pluginsIncludeDir = pluginsDir.childDirectory('include');
    if (pluginsIncludeDir.existsSync()) {
      copyDirectory(pluginsIncludeDir, incDir);
    }
    final Directory pluginsResDir = pluginsDir.childDirectory('res');
    if (pluginsResDir.existsSync()) {
      copyDirectory(pluginsResDir, resDir);
    }
    final Directory pluginsLibDir = pluginsDir.childDirectory('lib');
    if (pluginsLibDir.existsSync()) {
      copyDirectory(pluginsLibDir, libDir);
    }

    final Directory commonDir = getCommonArtifactsDirectory();
    final Directory clientWrapperDir =
        commonDir.childDirectory('cpp_client_wrapper');
    final Directory publicDir = commonDir.childDirectory('public');
    copyDirectory(clientWrapperDir.childDirectory('include'), incDir);
    copyDirectory(publicDir, incDir);

    final Directory embeddingDir =
        environment.buildDir.childDirectory('tizen_embedding');
    copyDirectory(embeddingDir.childDirectory('include'), incDir);

    final File embeddingLib = embeddingDir.childFile('libembedding_cpp.a');
    embeddingLib.copySync(buildDir.childFile(embeddingLib.basename).path);
  }
}
