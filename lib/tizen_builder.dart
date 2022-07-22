// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/gradle.dart';
import 'package:flutter_tools/src/base/analyze_size.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
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

import 'build_targets/package.dart';
import 'tizen_build_info.dart';
import 'tizen_project.dart';
import 'tizen_sdk.dart';

/// The define to control what Tizen device is built for.
const String kDeviceProfile = 'DeviceProfile';

TizenBuilder? get tizenBuilder => context.get<TizenBuilder>();

/// See:
/// - [AndroidGradleBuilder.buildApk] in `gradle.dart`
/// - [BuildIOSFrameworkCommand._produceAppFramework] in `build_ios_framework.dart` (build target)
/// - [AssembleCommand.runCommand] in `assemble.dart` (performance measurement)
/// - [buildLinux] in `build_linux.dart` (code size)
class TizenBuilder {
  TizenBuilder();

  Future<void> buildTpk({
    required FlutterProject project,
    required TizenBuildInfo tizenBuildInfo,
    required String targetFile,
    SizeAnalyzer? sizeAnalyzer,
  }) async {
    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    if (!tizenProject.existsSync()) {
      throwToolExit('This project is not configured for Tizen.');
    }
    if (tizenSdk == null || !tizenSdk!.tizenCli.existsSync()) {
      throwToolExit(
        'Unable to locate Tizen CLI executable.\n'
        'Run "flutter-tizen doctor" and install required components.',
      );
    }

    final Directory outputDir =
        project.directory.childDirectory('build').childDirectory('tizen');
    final BuildInfo buildInfo = tizenBuildInfo.buildInfo;
    // Used by AotElfBase to generate an AOT snapshot.
    final String targetPlatform = getNameForTargetPlatform(
        getTargetPlatformForArch(tizenBuildInfo.targetArch));

    final Environment environment = Environment(
      projectDir: project.directory,
      outputDir: outputDir,
      buildDir: project.dartTool.childDirectory('flutter_build'),
      cacheDir: globals.cache.getRoot(),
      flutterRootDir: globals.fs.directory(Cache.flutterRoot),
      engineVersion: globals.artifacts!.isLocalEngine
          ? null
          : globals.flutterVersion.engineRevision,
      defines: <String, String>{
        kTargetFile: targetFile,
        kTargetPlatform: targetPlatform,
        ...buildInfo.toBuildSystemEnvironment(),
        kDeviceProfile: tizenBuildInfo.deviceProfile,
      },
      artifacts: globals.artifacts!,
      fileSystem: globals.fs,
      logger: globals.logger,
      processManager: globals.processManager,
      platform: globals.platform,
      generateDartPluginRegistry: false,
    );

    final Target target = tizenProject.isDotnet
        ? DotnetTpk(tizenBuildInfo)
        : NativeTpk(tizenBuildInfo);

    final String buildModeName = getNameForBuildMode(buildInfo.mode);
    final Status status = globals.logger.startProgress(
        'Building a Tizen application in $buildModeName mode...');
    try {
      final BuildResult result =
          await globals.buildSystem.build(target, environment);
      if (!result.success) {
        for (final ExceptionMeasurement measurement
            in result.exceptions.values) {
          globals.printError(measurement.exception.toString());
        }
        throwToolExit('The build failed.');
      }

      if (buildInfo.performanceMeasurementFile != null) {
        final File outFile =
            globals.fs.file(buildInfo.performanceMeasurementFile);
        // ignore: invalid_use_of_visible_for_testing_member
        writePerformanceData(result.performance.values, outFile);
      }
    } finally {
      status.stop();
    }

    final Directory tpkDir = outputDir.childDirectory('tpk');
    final File tpkFile = tpkDir.childFile(tizenProject.outputTpkName);
    if (!tpkFile.existsSync()) {
      throwToolExit('The output TPK does not exist.');
    }
    final String relativeTpkPath = globals.fs.path.relative(tpkFile.path);
    final String tpkSize = getSizeAsMB(tpkFile.lengthSync());
    globals.printStatus(
      '${globals.logger.terminal.successMark} Built $relativeTpkPath ($tpkSize).',
      color: TerminalColor.green,
    );

    final Directory tpkrootDir = tpkDir.childDirectory('tpkroot');
    if (buildInfo.codeSizeDirectory != null && tpkrootDir.existsSync()) {
      sizeAnalyzer ??= SizeAnalyzer(
        fileSystem: globals.fs,
        logger: globals.logger,
        flutterUsage: globals.flutterUsage,
      );
      final File codeSizeFile = globals.fs
          .directory(buildInfo.codeSizeDirectory)
          .childFile('snapshot.$targetPlatform.json');
      final File precompilerTrace = globals.fs
          .directory(buildInfo.codeSizeDirectory)
          .childFile('trace.$targetPlatform.json');
      final Map<String, Object?> output = await sizeAnalyzer.analyzeAotSnapshot(
        aotSnapshot: codeSizeFile,
        outputDirectory: tpkrootDir,
        precompilerTrace: precompilerTrace,
        type: 'linux',
      );
      final File outputFile = globals.fsUtils.getUniqueFile(
        globals.fs
            .directory(globals.fsUtils.homeDirPath)
            .childDirectory('.flutter-devtools'),
        'tpk-code-size-analysis',
        'json',
      )..writeAsStringSync(jsonEncode(output));
      globals.printStatus(
        'A summary of your TPK analysis can be found at: ${outputFile.path}',
      );

      // DevTools expects a file path relative to the .flutter-devtools/ dir.
      final String relativeAppSizePath =
          outputFile.path.split('.flutter-devtools/').last.trim();
      globals.printStatus(
        '\nTo analyze your app size in Dart DevTools, run the following commands:\n\n'
        '\$ flutter-tizen pub global activate devtools\n'
        '\$ flutter-tizen pub global run devtools --appSizeBase=$relativeAppSizePath\n',
      );
    }
  }

  Future<void> buildModule({
    required FlutterProject project,
    required TizenBuildInfo tizenBuildInfo,
    required String targetFile,
  }) async {
    // TODO: Add relevant tests.

    // TODO: Minimize code duplication.
    // TODO: Assert: tizenProject should always exist here.
    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    if (!tizenProject.existsSync()) {
      throwToolExit('This project is not configured for Tizen.');
    }
    if (tizenSdk == null || !tizenSdk!.tizenCli.existsSync()) {
      throwToolExit(
        'Unable to locate Tizen CLI executable.\n'
        'Run "flutter-tizen doctor" and install required components.',
      );
    }

    final Directory outputDir =
        project.directory.childDirectory('build').childDirectory('tizen');
    final BuildInfo buildInfo = tizenBuildInfo.buildInfo;
    // Used by AotElfBase to generate an AOT snapshot.
    final String targetPlatform = getNameForTargetPlatform(
        getTargetPlatformForArch(tizenBuildInfo.targetArch));

    final Environment environment = Environment(
      projectDir: project.directory,
      outputDir: outputDir,
      buildDir: project.dartTool.childDirectory('flutter_build'),
      cacheDir: globals.cache.getRoot(),
      flutterRootDir: globals.fs.directory(Cache.flutterRoot),
      engineVersion: globals.artifacts!.isLocalEngine
          ? null
          : globals.flutterVersion.engineRevision,
      defines: <String, String>{
        kTargetFile: targetFile,
        kTargetPlatform: targetPlatform,
        ...buildInfo.toBuildSystemEnvironment(),
        kDeviceProfile: tizenBuildInfo.deviceProfile,
      },
      artifacts: globals.artifacts!,
      fileSystem: globals.fs,
      logger: globals.logger,
      processManager: globals.processManager,
      platform: globals.platform,
      generateDartPluginRegistry: false,
    );

    final String buildModeName = getNameForBuildMode(buildInfo.mode);
    final Status status = globals.logger.startProgress(
        'Building a Tizen application in $buildModeName mode...');
    try {
      final Target target = NativeModule(tizenBuildInfo);
      final BuildResult result =
          await globals.buildSystem.build(target, environment);
      if (!result.success) {
        for (final ExceptionMeasurement measurement
            in result.exceptions.values) {
          globals.printError(measurement.exception.toString());
        }
        throwToolExit('The build failed.');
      }

      if (buildInfo.performanceMeasurementFile != null) {
        final File outFile =
            globals.fs.file(buildInfo.performanceMeasurementFile);
        // ignore: invalid_use_of_visible_for_testing_member
        writePerformanceData(result.performance.values, outFile);
      }
    } finally {
      status.stop();
    }
  }
}
