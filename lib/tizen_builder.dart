// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/gradle.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/analyze_size.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/base/utils.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/assemble.dart';
import 'package:flutter_tools/src/commands/build_ios_framework.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/linux/build_linux.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/reporting/reporting.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'build_targets/application.dart';
import 'build_targets/package.dart';
import 'tizen_project.dart';
import 'tizen_sdk.dart';
import 'tizen_tpk.dart';

/// The define to control what Tizen device is built for.
const String kDeviceProfile = 'DeviceProfile';

TizenBuilder get tizenBuilder => context.get<TizenBuilder>();

/// See: [AndroidBuildInfo] in `build_info.dart`
class TizenBuildInfo {
  const TizenBuildInfo(
    this.buildInfo, {
    @required this.targetArch,
    @required this.deviceProfile,
    this.securityProfile,
  })  : assert(targetArch != null),
        assert(deviceProfile != null);

  final BuildInfo buildInfo;
  final String targetArch;
  final String deviceProfile;
  final String securityProfile;
}

/// See:
/// - [AndroidGradleBuilder.buildApk] in `gradle.dart`
/// - [BuildIOSFrameworkCommand._produceAppFramework] in `build_ios_framework.dart` (build target)
/// - [AssembleCommand.runCommand] in `assemble.dart` (performance measurement)
/// - [buildLinux] in `build_linux.dart` (code size)
class TizenBuilder {
  TizenBuilder({
    @required Logger logger,
    @required ProcessManager processManager,
    @required FileSystem fileSystem,
    @required Artifacts artifacts,
    @required Usage usage,
    @required Platform platform,
  })  : _logger = logger,
        _processManager = processManager,
        _fileSystem = fileSystem,
        _artifacts = artifacts,
        _usage = usage,
        _platform = platform,
        _fileSystemUtils =
            FileSystemUtils(fileSystem: fileSystem, platform: platform);

  final Logger _logger;
  final ProcessManager _processManager;
  final FileSystem _fileSystem;
  final Artifacts _artifacts;
  final Usage _usage;
  final Platform _platform;
  final FileSystemUtils _fileSystemUtils;

  Future<void> buildTpk({
    @required FlutterProject project,
    @required TizenBuildInfo tizenBuildInfo,
    @required String targetFile,
  }) async {
    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    if (!tizenProject.existsSync()) {
      throwToolExit(
        'This project is not configured for Tizen.\n'
        'To fix this problem, create a new project by running `flutter-tizen create <app-dir>`.',
      );
    }
    if (tizenSdk == null || !tizenSdk.tizenCli.existsSync()) {
      throwToolExit(
        'Unable to locate Tizen CLI executable.\n'
        'Run "flutter-tizen doctor" and install required components.',
      );
    }

    _updateManifest(tizenProject, tizenBuildInfo);

    final Directory outputDir =
        project.directory.childDirectory('build').childDirectory('tizen');
    final BuildInfo buildInfo = tizenBuildInfo.buildInfo;
    // Used by AotElfBase to generate an AOT snapshot.
    final String targetPlatform = getNameForTargetPlatform(
        _getTargetPlatformForArch(tizenBuildInfo.targetArch));

    final Environment environment = Environment(
      projectDir: project.directory,
      outputDir: outputDir,
      buildDir: project.dartTool.childDirectory('flutter_build'),
      cacheDir: globals.cache.getRoot(),
      flutterRootDir: _fileSystem.directory(Cache.flutterRoot),
      engineVersion: globals.flutterVersion.engineRevision,
      defines: <String, String>{
        kTargetFile: targetFile,
        kTargetPlatform: targetPlatform,
        ...buildInfo.toBuildSystemEnvironment(),
        kDeviceProfile: tizenBuildInfo.deviceProfile,
      },
      artifacts: _artifacts,
      fileSystem: _fileSystem,
      logger: _logger,
      processManager: _processManager,
      platform: _platform,
      generateDartPluginRegistry: true,
    );

    final Target target = buildInfo.isDebug
        ? DebugTizenApplication(tizenBuildInfo)
        : ReleaseTizenApplication(tizenBuildInfo);

    final String buildModeName = getNameForBuildMode(buildInfo.mode);
    final Status status = _logger.startProgress(
        'Building a Tizen application in $buildModeName mode...');
    try {
      final BuildResult result =
          await globals.buildSystem.build(target, environment);
      if (!result.success) {
        for (final ExceptionMeasurement measurement
            in result.exceptions.values) {
          _logger.printError(measurement.exception.toString());
        }
        throwToolExit('The build failed.');
      }

      // These pseudo targets cannot be skipped and should be invoked whenever
      // the build is run.
      if (tizenProject.isDotnet) {
        await DotnetTpk(tizenBuildInfo).build(environment);
      } else {
        await NativeTpk(tizenBuildInfo).build(environment);
      }

      if (buildInfo.performanceMeasurementFile != null) {
        final File outFile =
            _fileSystem.file(buildInfo.performanceMeasurementFile);
        // ignore: invalid_use_of_visible_for_testing_member
        writePerformanceData(result.performance.values, outFile);
      }
    } finally {
      status.stop();
    }

    final Directory tpkDir = outputDir.childDirectory('tpk');
    final File tpkFile = tpkDir.childFile(tizenProject.outputTpkName);
    final String relativeTpkPath = _fileSystem.path.relative(tpkFile.path);
    final String tpkSize = getSizeAsMB(tpkFile.lengthSync());
    _logger.printStatus(
      '${_logger.terminal.successMark} Built $relativeTpkPath ($tpkSize).',
      color: TerminalColor.green,
    );

    final Directory tpkrootDir = tpkDir.childDirectory('tpkroot');
    if (buildInfo.codeSizeDirectory != null && tpkrootDir.existsSync()) {
      final SizeAnalyzer sizeAnalyzer = SizeAnalyzer(
        fileSystem: _fileSystem,
        logger: _logger,
        flutterUsage: _usage,
      );
      final File codeSizeFile = _fileSystem
          .directory(buildInfo.codeSizeDirectory)
          .childFile('snapshot.$targetPlatform.json');
      final File precompilerTrace = _fileSystem
          .directory(buildInfo.codeSizeDirectory)
          .childFile('trace.$targetPlatform.json');
      final Map<String, Object> output = await sizeAnalyzer.analyzeAotSnapshot(
        aotSnapshot: codeSizeFile,
        outputDirectory: tpkrootDir,
        precompilerTrace: precompilerTrace,
        type: 'linux',
      );
      final File outputFile = _fileSystemUtils.getUniqueFile(
        _fileSystem
            .directory(_fileSystemUtils.homeDirPath)
            .childDirectory('.flutter-devtools'),
        'tpk-code-size-analysis',
        'json',
      )..writeAsStringSync(jsonEncode(output));
      _logger.printStatus(
        'A summary of your TPK analysis can be found at: ${outputFile.path}',
      );

      // DevTools expects a file path relative to the .flutter-devtools/ dir.
      final String relativeAppSizePath =
          outputFile.path.split('.flutter-devtools/').last.trim();
      _logger.printStatus(
        '\nTo analyze your app size in Dart DevTools, run the following commands:\n\n'
        '\$ flutter-tizen pub global activate devtools\n'
        '\$ flutter-tizen pub global run devtools --appSizeBase=$relativeAppSizePath\n',
      );
    }
  }

  /// Updates tizen-manifest.xml with the given build info.
  void _updateManifest(TizenProject project, TizenBuildInfo buildInfo) {
    void updateManifestFile(File manifestFile) {
      final TizenManifest manifest = TizenManifest.parseFromXml(manifestFile);
      final String buildName =
          buildInfo.buildInfo.buildName ?? project.parent.manifest.buildName;
      if (buildName != null) {
        manifest.version = buildName;
      }
      final String deviceProfile = buildInfo.deviceProfile;
      if (deviceProfile != null) {
        manifest.profile = deviceProfile;
      }
      manifestFile.writeAsStringSync('$manifest\n');
    }

    if (project.isMultiApp) {
      updateManifestFile(project.uiManifestFile);
      updateManifestFile(project.serviceManifestFile);
    } else {
      updateManifestFile(project.manifestFile);
    }
  }
}

/// See: [getTargetPlatformForName] in `build_info.dart`
TargetPlatform _getTargetPlatformForArch(String arch) {
  switch (arch) {
    case 'arm64':
      return TargetPlatform.android_arm64;
    case 'x86':
      return TargetPlatform.android_x86;
    default:
      return TargetPlatform.android_arm;
  }
}
