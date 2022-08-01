// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/source.dart';
import 'package:flutter_tools/src/project.dart';

import '../tizen_build_info.dart';
import '../tizen_plugins.dart';
import '../tizen_project.dart';
import '../tizen_sdk.dart';
import '../tizen_tpk.dart';
import 'utils.dart';

/// Compiles Tizen native plugins into a shared object.
class NativePlugins extends Target {
  NativePlugins(this.buildInfo);

  final TizenBuildInfo buildInfo;

  @override
  String get name => 'tizen_native_plugins';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{FLUTTER_ROOT}/../lib/build_targets/plugins.dart'),
        Source.pattern('{FLUTTER_ROOT}/../lib/tizen_sdk.dart'),
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

  void _checkProjectType(TizenPlugin plugin) {
    final Map<String, String> properties = parseIniFile(plugin.projectFile);
    final String? type = properties['type'];
    if (type != 'staticLib') {
      throwToolExit(
        'The project type of ${plugin.name} is "$type" which is not supported.\n'
        'Make sure the package is up to date by running "flutter-tizen pub upgrade".\n\n'
        'If you are the maintainer of the ${plugin.name} package, consider migrating the project to "staticLib" type.\n'
        'Otherwise, you may modify the value of "type" in ${plugin.projectFile.path} to temporarily fix the problem.',
      );
    }
  }

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

    // Check if there's anything to build.
    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, cppOnly: true);
    if (nativePlugins.isEmpty) {
      depfileService.writeToFile(
        Depfile(inputs, outputs),
        environment.buildDir.childFile('tizen_plugins.d'),
      );
      return;
    }

    // Create a dummy project in the build directory.
    final Directory rootDir = environment.buildDir
        .childDirectory('tizen_plugins')
      ..createSync(recursive: true);
    final Directory includeDir = rootDir.childDirectory('include')
      ..createSync(recursive: true);
    final Directory resDir = rootDir.childDirectory('res')
      ..createSync(recursive: true);
    final Directory libDir = rootDir.childDirectory('lib')
      ..createSync(recursive: true);

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final String buildConfig = getBuildConfig(buildMode);
    final Directory engineDir =
        getEngineArtifactsDirectory(buildInfo.targetArch, buildMode);
    final Directory commonDir = engineDir.parent.childDirectory('tizen-common');

    final Directory clientWrapperDir =
        commonDir.childDirectory('cpp_client_wrapper');
    final Directory publicDir = commonDir.childDirectory('public');
    clientWrapperDir
        .listSync(recursive: true)
        .whereType<File>()
        .forEach(inputs.add);
    publicDir.listSync(recursive: true).whereType<File>().forEach(inputs.add);

    assert(tizenSdk != null);
    final TizenManifest tizenManifest =
        TizenManifest.parseFromXml(tizenProject.manifestFile);
    final String profile = buildInfo.deviceProfile;
    final String? apiVersion = tizenManifest.apiVersion;
    final Rootstrap rootstrap = tizenSdk!.getFlutterRootstrap(
      profile: profile,
      apiVersion: apiVersion,
      arch: buildInfo.targetArch,
    );
    inputs.add(tizenProject.manifestFile);

    final List<String> userLibs = <String>[];
    final List<String> pluginClasses = <String>[];

    for (final TizenPlugin plugin in nativePlugins) {
      _checkProjectType(plugin);
      inputs.add(plugin.projectFile);

      final Directory buildDir = plugin.directory.childDirectory(buildConfig);
      if (buildDir.existsSync()) {
        buildDir.deleteSync(recursive: true);
      }
      final RunResult result = await tizenSdk!.buildNative(
        plugin.directory.path,
        configuration: buildConfig,
        arch: getTizenCliArch(buildInfo.targetArch),
        predefines: <String>[
          '${buildInfo.deviceProfile.toUpperCase()}_PROFILE',
        ],
        extraOptions: <String>[
          '-fPIC',
          '-I${clientWrapperDir.childDirectory('include').path.toPosixPath()}',
          '-I${publicDir.path.toPosixPath()}',
        ],
        rootstrap: rootstrap.id,
      );
      if (result.exitCode != 0) {
        throwToolExit('Failed to build ${plugin.name} plugin:\n$result');
      }

      assert(plugin.fileName != null);
      assert(plugin.pluginClass != null);
      final String libName =
          getLibNameForFileName(plugin.fileName!.toLowerCase());
      final File libFile = buildDir.childFile('lib$libName.a');
      if (!libFile.existsSync()) {
        throwToolExit(
          'Build succeeded but the file ${libFile.path} is not found:\n'
          '${result.stdout}',
        );
      }
      libFile.copySync(libDir.childFile(libFile.basename).path);
      userLibs.add(libName);
      pluginClasses.add(plugin.pluginClass!);

      final Directory pluginIncludeDir = plugin.directory.childDirectory('inc');
      if (pluginIncludeDir.existsSync()) {
        pluginIncludeDir
            .listSync(recursive: true)
            .whereType<File>()
            .forEach(inputs.add);
      }
      final Directory pluginSourceDir = plugin.directory.childDirectory('src');
      if (pluginSourceDir.existsSync()) {
        pluginSourceDir
            .listSync(recursive: true)
            .whereType<File>()
            .forEach(inputs.add);
      }

      // Copy resource files.
      final Directory pluginResDir = plugin.directory.childDirectory('res');
      if (pluginResDir.existsSync()) {
        copyDirectory(
          pluginResDir,
          resDir.childDirectory(plugin.name),
          onFileCopied: (File srcFile, File destFile) {
            inputs.add(srcFile);
            outputs.add(destFile);
          },
        );
      }

      // Copy user libs for later linking.
      final Directory pluginLibDir = plugin.directory.childDirectory('lib');
      final List<Directory> pluginLibDirs = <Directory>[
        pluginLibDir.childDirectory(buildInfo.targetArch),
        pluginLibDir.childDirectory(getTizenBuildArch(buildInfo.targetArch)),
        pluginLibDir,
      ];
      for (final Directory directory
          in pluginLibDirs.where((Directory d) => d.existsSync())) {
        for (final File lib in directory.listSync().whereType<File>()) {
          final bool isSharedLib = lib.basename.endsWith('.so');
          final bool isStaticLib = lib.basename.endsWith('.a');
          if (isSharedLib || isStaticLib) {
            final String libName = getLibNameForFileName(lib.basename);
            if (userLibs.contains(libName)) {
              continue;
            }
            lib.copySync(libDir.childFile(lib.basename).path);
            userLibs.add(libName);

            inputs.add(lib);
            if (isSharedLib) {
              outputs.add(libDir.childFile(lib.basename));
            }
          }
        }
      }

      // The plugin header is used by the native app builder.
      final File header = pluginIncludeDir.childFile(plugin.fileName!);
      header.copySync(includeDir.childFile(header.basename).path);
      outputs.add(includeDir.childFile(header.basename));
    }

    // The absolute path to clientWrapperDir may contain spaces.
    // We need to copy the entire directory into the build directory because
    // USER_SRCS in project_def.prop doesn't allow spaces.
    copyDirectory(
        clientWrapperDir, rootDir.childDirectory(clientWrapperDir.basename));

    final File projectDef = rootDir.childFile('project_def.prop');
    projectDef.writeAsStringSync('''
APPNAME = flutter_plugins
type = sharedLib
profile = $profile-$apiVersion

USER_INC_DIRS = ${clientWrapperDir.basename}/include
USER_SRCS = ${clientWrapperDir.basename}/*.cc

USER_LFLAGS = -Wl,-rpath='\$\$ORIGIN'
USER_LIBS = pthread ${userLibs.join(' ')}
''');

    final File embedder =
        engineDir.childFile('libflutter_tizen_${buildInfo.deviceProfile}.so');
    inputs.add(embedder);

    final Directory buildDir = rootDir.childDirectory(buildConfig);
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }
    final RunResult result = await tizenSdk!.buildNative(
      rootDir.path,
      configuration: buildConfig,
      arch: getTizenCliArch(buildInfo.targetArch),
      extraOptions: <String>[
        '-l${getLibNameForFileName(embedder.basename)}',
        '-L${engineDir.path.toPosixPath()}',
        '-I${publicDir.path.toPosixPath()}',
        '-L${libDir.path.toPosixPath()}',
        // Forces plugin entrypoints to be exported, because unreferenced
        // objects are not included in the output shared object by default.
        // Another option is to use the -Wl,--[no-]whole-archive flag.
        for (String className in pluginClasses)
          '-Wl,--undefined=${className}RegisterWithRegistrar',
      ],
      rootstrap: rootstrap.id,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to build native plugins:\n$result');
    }

    final File outputLib = buildDir.childFile('libflutter_plugins.so');
    if (!outputLib.existsSync()) {
      throwToolExit(
        'Build succeeded but the file ${outputLib.path} is not found:\n'
        '${result.stdout}',
      );
    }
    outputs.add(outputLib.copySync(rootDir.childFile(outputLib.basename).path));

    // Remove intermediate files.
    for (final File lib in libDir
        .listSync()
        .whereType<File>()
        .where((File f) => f.basename.endsWith('.a'))) {
      lib.deleteSync();
    }

    depfileService.writeToFile(
      Depfile(inputs, outputs),
      environment.buildDir.childFile('tizen_plugins.d'),
    );
  }
}
