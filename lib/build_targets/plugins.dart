// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/source.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

import '../tizen_builder.dart';
import '../tizen_plugins.dart';
import '../tizen_project.dart';
import '../tizen_sdk.dart';
import '../tizen_tpk.dart';
import 'utils.dart';

/// Compiles Tizen native plugins into a shared object.
class NativePlugins extends Target {
  NativePlugins(this.buildInfo);

  final TizenBuildInfo buildInfo;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  @override
  String get name => 'tizen_native_plugins';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{FLUTTER_ROOT}/../lib/tizen_build_target.dart'),
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
    final List<File> inputs = <File>[];
    final List<File> outputs = <File>[];
    final DepfileService depfileService = DepfileService(
      fileSystem: environment.fileSystem,
      logger: environment.logger,
    );

    final FlutterProject project =
        FlutterProject.fromDirectory(environment.projectDir);
    final TizenProject tizenProject = TizenProject.fromFlutter(project);

    // Create a dummy project in the build directory.
    final Directory rootDir = environment.buildDir
        .childDirectory('tizen_plugins')
          ..createSync(recursive: true);
    final File projectDef = rootDir.childFile('project_def.prop');

    final TizenManifest tizenManifest =
        TizenManifest.parseFromXml(tizenProject.manifestFile);
    final String profile = tizenManifest.profile;
    final String apiVersion = tizenManifest.apiVersion;
    inputs.add(tizenProject.manifestFile);

    projectDef.writeAsStringSync('''
APPNAME = flutter_plugins
type = sharedLib
profile = $profile-$apiVersion

USER_CPP_DEFS = TIZEN_DEPRECATION DEPRECATION_WARNING FLUTTER_PLUGIN_IMPL
USER_CPPFLAGS_MISC = -c -fmessage-length=0
USER_LFLAGS = -Wl,-rpath='\$\$ORIGIN'
''');

    // Check if there's anything to build.
    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, nativeOnly: true);
    if (nativePlugins.isEmpty) {
      rootDir.deleteSync(recursive: true);

      depfileService.writeToFile(
        Depfile(inputs, outputs),
        environment.buildDir.childFile('tizen_plugins.d'),
      );
      return;
    }

    // Prepare for build.
    final Directory includeDir = rootDir.childDirectory('include')
      ..createSync(recursive: true);
    final Directory libDir = rootDir.childDirectory('lib')
      ..createSync(recursive: true);

    final List<String> userIncludes = <String>[];
    final List<String> userSources = <String>[];
    final List<String> userLibs = <String>[];

    for (final TizenPlugin plugin in nativePlugins) {
      inputs.add(plugin.projectFile);

      // TODO(swift-kim): Currently only checks for USER_INC_DIRS, USER_SRCS,
      // and USER_LIBS. More properties may be parsed in the future.
      userIncludes.addAll(plugin.getPropertyAsAbsolutePaths('USER_INC_DIRS'));
      userSources.addAll(plugin.getPropertyAsAbsolutePaths('USER_SRCS'));

      final Directory headerDir = plugin.directory.childDirectory('inc');
      if (headerDir.existsSync()) {
        headerDir
            .listSync(recursive: true)
            .whereType<File>()
            .forEach(inputs.add);
      }
      final Directory sourceDir = plugin.directory.childDirectory('src');
      if (sourceDir.existsSync()) {
        sourceDir
            .listSync(recursive: true)
            .whereType<File>()
            .forEach(inputs.add);
      }

      for (final String libName in plugin.getProperty('USER_LIBS')) {
        File libFile = plugin.directory
            .childDirectory('lib')
            .childDirectory(getTizenBuildArch(buildInfo.targetArch))
            .childFile('lib$libName.a');
        if (!libFile.existsSync()) {
          libFile = libFile.parent.childFile('lib$libName.so');
          if (!libFile.existsSync()) {
            continue;
          }
        }
        userLibs.add(libName);
        libFile.copySync(libDir.childFile(libFile.basename).path);

        inputs.add(libFile);
        outputs.add(libDir.childFile(libFile.basename));
      }

      // The plugin header is used when building native apps.
      final File header = headerDir.childFile(plugin.fileName);
      header.copySync(includeDir.childFile(header.basename).path);
      outputs.add(includeDir.childFile(header.basename));
    }

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final Directory engineDir =
        getEngineArtifactsDirectory(buildInfo.targetArch, buildMode);
    final File embedder =
        engineDir.childFile('libflutter_tizen_${buildInfo.deviceProfile}.so');
    inputs.add(embedder);

    final Directory commonDir = engineDir.parent.childDirectory('tizen-common');
    final Directory clientWrapperDir =
        commonDir.childDirectory('cpp_client_wrapper');
    final Directory publicDir = commonDir.childDirectory('public');
    clientWrapperDir
        .listSync(recursive: true)
        .whereType<File>()
        .forEach(inputs.add);
    publicDir.listSync(recursive: true).whereType<File>().forEach(inputs.add);

    userSources.add(clientWrapperDir.childFile('*.cc').path);

    final Map<String, String> variables = <String, String>{
      'PATH': getDefaultPathVariable(),
      'USER_SRCS': userSources.map((String f) => f.toPosixPath()).join(' '),
      'USER_LIBS': userLibs.join(' '),
    };
    final List<String> extraOptions = <String>[
      '-lflutter_tizen_${buildInfo.deviceProfile}',
      '-L"${engineDir.path.toPosixPath()}"',
      '-fvisibility=hidden',
      '-I"${clientWrapperDir.childDirectory('include').path.toPosixPath()}"',
      '-I"${publicDir.path.toPosixPath()}"',
      ...userIncludes.map((String f) => '-I"${f.toPosixPath()}"'),
      '-L"${libDir.path.toPosixPath()}"',
      '-D${buildInfo.deviceProfile.toUpperCase()}_PROFILE',
    ];

    assert(tizenSdk != null);
    final Rootstrap rootstrap = tizenSdk.getFlutterRootstrap(
      profile: profile,
      apiVersion: apiVersion,
      arch: buildInfo.targetArch,
    );

    // Create a temp directory to use as a build directory.
    // This is a workaround for the long path issue on Windows:
    // https://github.com/flutter-tizen/flutter-tizen/issues/122
    final Directory tempDir = environment.fileSystem.systemTempDirectory
        .childDirectory('0')
          ..createSync(recursive: true);
    projectDef.copySync(tempDir.childFile(projectDef.basename).path);

    final String buildConfig = buildMode.isPrecompiled ? 'Release' : 'Debug';
    final Directory buildDir = tempDir.childDirectory(buildConfig);

    // Run the native build.
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
      tempDir.path,
    ], environment: variables);
    if (result.exitCode != 0) {
      throwToolExit('Failed to build Flutter plugins:\n$result');
    }

    final File outputLib = buildDir.childFile('libflutter_plugins.so');
    if (!outputLib.existsSync()) {
      throwToolExit(
        'Build succeeded but the file ${outputLib.path} is not found:\n'
        '${result.stdout}',
      );
    }

    final File outputLibCopy =
        outputLib.copySync(rootDir.childFile(outputLib.basename).path);
    outputs.add(outputLibCopy);

    depfileService.writeToFile(
      Depfile(inputs, outputs),
      environment.buildDir.childFile('tizen_plugins.d'),
    );
  }
}
