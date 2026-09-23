// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/fingerprint.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

import '../tizen_build_info.dart';
import '../tizen_plugins.dart';
import '../tizen_project.dart';
import '../tizen_sdk.dart';
import '../tizen_tpk.dart';
import 'utils.dart';

/// Returns the libraries that the C++ embedding built for [apiVersion] links to.
List<String> getEmbeddingDependencies(String? apiVersion) => <String>[
      'appcore-agent',
      'capi-appfw-app-common',
      'capi-appfw-application',
      'capi-appfw-app-manager',
      'dlog',
      if (usesTizenCoreEmbedder(apiVersion)) 'tizen-core',
    ];

Directory get _flutterTizenRoot => globals.fs.directory(Cache.flutterRoot).parent;

Directory get _embeddingDirectory =>
    _flutterTizenRoot.childDirectory('embedding').childDirectory('cpp');

class NativeEmbedding extends Target {
  NativeEmbedding(this.buildInfo);

  final TizenBuildInfo buildInfo;

  @override
  String get name => 'tizen_cpp_embedding';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{FLUTTER_ROOT}/../lib/build_targets/embedding.dart'),
        Source.pattern('{FLUTTER_ROOT}/../lib/build_targets/utils.dart'),
        Source.pattern('{FLUTTER_ROOT}/../lib/tizen_plugins.dart'),
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
    final BuildMode buildMode = buildInfo.buildInfo.mode;
    if (tizenProject.manifestFile.existsSync()) {
      inputs.add(tizenProject.manifestFile);
    }

    // The prebuilt runner has the embedding compiled in, so the static library
    // is only needed to link libflutter_plugins.so. Track the plugin
    // declarations to build it as soon as a C++ plugin is added.
    if (tizenProject.usesPrebuiltRunner) {
      final Directory dartToolDir = project.directory.childDirectory('.dart_tool');
      inputs.addAll(<File>[
        dartToolDir.childFile('package_config.json'),
        dartToolDir.childFile('package_graph.json'),
      ].where((File file) => file.existsSync()));
      inputs.addAll(await findDependencyPubspecs(project));
      List<TizenPlugin> cppPlugins = await findTizenPlugins(project, cppOnly: true);
      if (buildMode.isRelease) {
        cppPlugins = cppPlugins.where((TizenPlugin p) => !p.isDevDependency).toList();
      }
      if (cppPlugins.isEmpty) {
        depfileService.writeToFile(
          Depfile(inputs, outputs),
          environment.buildDir.childFile('tizen_embedding.d'),
        );
        return;
      }
    }

    final Directory outputDir = environment.buildDir.childDirectory('tizen_embedding')
      ..createSync(recursive: true);
    final Directory embeddingDir = _embeddingDirectory;
    embeddingDir.listSync().whereType<File>().forEach(inputs.add);
    copyDirectory(
      embeddingDir.childDirectory('include'),
      outputDir.childDirectory('include'),
      onFileCopied: (File srcFile, File destFile) {
        inputs.add(srcFile);
        outputs.add(destFile);
      },
    );

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
      apiVersion = getBuildApiVersion(
        TizenManifest.parseFromXml(tizenProject.manifestFile).apiVersion,
        buildInfo.targetArch,
      );
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

/// Returns the prebuilt runner of apps created with `--tizen-language=native`.
///
/// The runner has no app-specific code, so it is built from
/// `embedding/cpp/runner` only once per configuration and cached in the Flutter
/// cache. App builds only copy it into the package.
Future<File> ensurePrebuiltRunner(
  TizenBuildInfo buildInfo, {
  required Rootstrap rootstrap,
  required File embedder,
  required String? apiVersion,
}) async {
  final String buildConfig = getBuildConfig(buildInfo.buildInfo.mode);
  final Directory cacheDir = globals.cache
      .getArtifactDirectory('tizen-runner')
      .childDirectory(rootstrap.id)
      .childDirectory(getLibNameForFileName(embedder.basename))
      .childDirectory(buildConfig);
  final File runner = cacheDir.childFile('runner');

  final Directory embeddingDir = _embeddingDirectory;
  final Directory commonDir = getCommonArtifactsDirectory();
  final Directory clientWrapperIncludeDir =
      commonDir.childDirectory('cpp_client_wrapper').childDirectory('include');
  final Directory publicDir = commonDir.childDirectory('public');

  // Skip the Debug and Release directories which contain build outputs.
  final sources = <File>[
    ...embeddingDir.listSync().whereType<File>(),
    for (final String name in <String>['include', 'runner'])
      ...embeddingDir.childDirectory(name).listSync(recursive: true).whereType<File>(),
  ];
  assert(tizenSdk != null);
  // The Tizen CLI configures the build with the rootstrap and toolchain
  // definitions of the SDK, so the runner is rebuilt when they change. The
  // toolchain binaries themselves are not hashed.
  final Directory sbiPluginsDir =
      tizenSdk!.toolsDirectory.childDirectory('smart-build-interface').childDirectory('plugins');
  final Iterable<File> sdkInputs = <File>[
    tizenSdk!.directory.childFile('sdk.version'),
    rootstrap.rootDirectory.parent.childDirectory('info').childFile('${rootstrap.id}.dev.xml'),
    sbiPluginsDir.childFile('${rootstrap.id}.xml'),
    if (sbiPluginsDir.existsSync())
      ...sbiPluginsDir
          .listSync()
          .whereType<File>()
          .where((File file) => file.basename.endsWith('.app.xml')),
  ].where((File file) => file.existsSync());

  final Directory libDir = _flutterTizenRoot.childDirectory('lib');
  final fingerprinter = Fingerprinter(
    fingerprintPath: cacheDir.childFile('runner.fingerprint').path,
    paths: <String>[
      libDir.childDirectory('build_targets').childFile('embedding.dart').path,
      libDir.childDirectory('build_targets').childFile('utils.dart').path,
      libDir.childFile('tizen_sdk.dart').path,
      embedder.path,
      for (final File file in sources) file.path,
      for (final Directory dir in <Directory>[clientWrapperIncludeDir, publicDir])
        for (final File file in dir.listSync(recursive: true).whereType<File>()) file.path,
      for (final File file in sdkInputs) file.path,
    ],
    fileSystem: globals.fs,
    logger: globals.logger,
  );
  if (runner.existsSync() && fingerprinter.doesFingerprintMatch()) {
    return runner;
  }

  // Build in a copy of the sources because the build tool writes the objects
  // of ../*.cc next to the project directory.
  final Directory workDir = globals.fs.systemTempDirectory.createTempSync('flutter_tizen_runner.');
  try {
    for (final source in sources) {
      final File copy =
          workDir.childFile(globals.fs.path.relative(source.path, from: embeddingDir.path));
      copy.parent.createSync(recursive: true);
      source.copySync(copy.path);
    }
    final Directory projectDir = workDir.childDirectory('runner');

    final RunResult result = await tizenSdk!.buildNative(
      projectDir.path,
      configuration: buildConfig,
      arch: getTizenCliArch(buildInfo.targetArch),
      predefines: <String>[
        '${buildInfo.deviceProfile.toUpperCase()}_PROFILE',
        if (usesTizenCoreEmbedder(apiVersion)) 'TIZEN_CORE',
      ],
      extraOptions: <String>[
        '-Wl,--unresolved-symbols=ignore-in-shared-libs',
        '-I${clientWrapperIncludeDir.path.toPosixPath()}',
        '-I${publicDir.path.toPosixPath()}',
        '-L${embedder.parent.path.toPosixPath()}',
        '-l${getLibNameForFileName(embedder.basename)}',
        for (final String lib in getEmbeddingDependencies(apiVersion)) '-l$lib',
        '-ldl',
      ],
      rootstrap: rootstrap.id,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to build the runner:\n$result');
    }

    final File output = projectDir.childDirectory(buildConfig).childFile('runner');
    if (!output.existsSync()) {
      throwToolExit(
        'Build succeeded but the file ${output.path} is not found:\n'
        '${result.stdout}',
      );
    }
    cacheDir.createSync(recursive: true);
    // Replace atomically through a temporary file unique to this build, as
    // other builds may be writing or reading the cache at the same time.
    final Directory tempDir = cacheDir.createTempSync('runner.');
    output.copySync(tempDir.childFile('runner').path);
    tempDir.childFile('runner').renameSync(runner.path);
    tempDir.deleteSync(recursive: true);
  } finally {
    workDir.deleteSync(recursive: true);
  }
  fingerprinter.writeFingerprint();
  return runner;
}
