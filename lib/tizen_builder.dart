// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_builder.dart';
import 'package:flutter_tools/src/android/gradle.dart';
import 'package:flutter_tools/src/base/analyze_size.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/base/utils.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/targets/assets.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/build_system/targets/icon_tree_shaker.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/assemble.dart';
import 'package:flutter_tools/src/commands/build_ios_framework.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/linux/build_linux.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'tizen_artifacts.dart';
import 'tizen_build_target.dart';
import 'tizen_project.dart';
import 'tizen_tpk.dart';

/// The define to control what Tizen architectures are built for.
/// This is expected to be a comma-separated list of architectures.
const String kTizenArchs = 'TizenArchs';

/// See: [AndroidBuildInfo] in `build_info.dart`
class TizenBuildInfo {
  const TizenBuildInfo(
    this.buildInfo, {
    @required this.targetArchs,
    this.deviceProfile,
    this.securityProfile,
  });

  final BuildInfo buildInfo;
  final List<String> targetArchs;
  final String deviceProfile;
  final String securityProfile;
}

/// See:
/// - [AndroidBuilder] in `android_builder.dart`
/// - [buildGradleApp] in `gradle.dart`
/// - [BuildIOSFrameworkCommand._produceAppFramework] in `build_ios_framework.dart` (build target)
/// - [AssembleCommand.runCommand] in `assemble.dart` (performance measurement)
/// - [buildLinux] in `build_linux.dart` (code size)
class TizenBuilder {
  static Future<void> buildTpk({
    @required FlutterProject project,
    @required TizenBuildInfo tizenBuildInfo,
    @required String targetFile,
    SizeAnalyzer sizeAnalyzer,
  }) async {
    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    if (!tizenProject.existsSync()) {
      throwToolExit(
        'This project is not configured for Tizen.\n'
        'To fix this problem, create a new project by running `flutter-tizen create <app-dir>`.',
      );
    }
    if (!tizenProject.isDotnet && tizenBuildInfo.targetArchs.length > 1) {
      throwToolExit(
          'Tizen native projects cannot be built for multiple target archs.');
    }

    updateManifest(tizenProject, tizenBuildInfo.buildInfo);

    final BuildInfo buildInfo = tizenBuildInfo.buildInfo;
    final Directory outputDir =
        project.directory.childDirectory('build').childDirectory('tizen');

    final Environment environment = Environment(
      projectDir: project.directory,
      outputDir: outputDir,
      buildDir: project.dartTool.childDirectory('flutter_build'),
      cacheDir: globals.cache.getRoot(),
      flutterRootDir: globals.fs.directory(Cache.flutterRoot),
      engineVersion: tizenArtifacts.isLocalEngine
          ? null
          : globals.flutterVersion.engineRevision,
      defines: <String, String>{
        kTizenArchs: tizenBuildInfo.targetArchs.join(','),
        kTargetFile: targetFile,
        kBuildMode: getNameForBuildMode(buildInfo.mode),
        kTargetPlatform: getNameForTargetPlatform(TargetPlatform.android),
        kDartObfuscation: buildInfo.dartObfuscation.toString(),
        kSplitDebugInfo: buildInfo.splitDebugInfoPath,
        kIconTreeShakerFlag: buildInfo.treeShakeIcons.toString(),
        kTrackWidgetCreation: buildInfo.trackWidgetCreation.toString(),
        kCodeSizeDirectory: buildInfo.codeSizeDirectory,
        if (buildInfo.dartDefines?.isNotEmpty ?? false)
          kDartDefines: encodeDartDefines(buildInfo.dartDefines),
        if (buildInfo.extraGenSnapshotOptions?.isNotEmpty ?? false)
          kExtraGenSnapshotOptions: buildInfo.extraGenSnapshotOptions.join(','),
        if (buildInfo.extraFrontEndOptions?.isNotEmpty ?? false)
          kExtraFrontEndOptions: buildInfo.extraFrontEndOptions.join(','),
      },
      inputs: <String, String>{
        kBundleSkSLPath: buildInfo.bundleSkSLPath,
      },
      artifacts: tizenArtifacts,
      fileSystem: globals.fs,
      logger: globals.logger,
      processManager: globals.processManager,
    );

    final Target target = buildInfo.isDebug
        ? DebugTizenAssetBundle(project, tizenBuildInfo)
        : ReleaseTizenAssetBundle(project, tizenBuildInfo);

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

      if (tizenProject.isDotnet) {
        await DotnetTpk(project, tizenBuildInfo).build(environment);
      } else {
        await NativeTpk(project, tizenBuildInfo).build(environment);
      }

      if (buildInfo.performanceMeasurementFile != null) {
        final File outFile =
            globals.fs.file(buildInfo.performanceMeasurementFile);
        writePerformanceMeasurementData(result.performance.values, outFile);
      }
    } finally {
      status.stop();
    }

    final File tpkFile = outputDir.childFile(tizenProject.outputTpkName);
    final String tpkSize = getSizeAsMB(tpkFile.lengthSync());
    globals.printStatus(
      '$successMark Built ${relative(tpkFile.path)} ($tpkSize).',
      color: TerminalColor.green,
    );

    if (buildInfo.codeSizeDirectory != null && sizeAnalyzer != null) {
      final String arch = tizenBuildInfo.targetArchs.first;
      final File codeSizeFile = globals.fs
          .directory(buildInfo.codeSizeDirectory)
          .childFile('snapshot.$arch.json');
      final File precompilerTrace = globals.fs
          .directory(buildInfo.codeSizeDirectory)
          .childFile('trace.$arch.json');
      final Map<String, Object> output = await sizeAnalyzer.analyzeAotSnapshot(
        aotSnapshot: codeSizeFile,
        outputDirectory: outputDir.childDirectory('tpkroot'),
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

  /// Source: [writePerformanceData] in `assemble.dart` (exact copy)
  static void writePerformanceMeasurementData(
      Iterable<PerformanceMeasurement> measurements, File outFile) {
    final Map<String, Object> jsonData = <String, Object>{
      'targets': <Object>[
        for (final PerformanceMeasurement measurement in measurements)
          <String, Object>{
            'name': measurement.analyticsName,
            'skipped': measurement.skipped,
            'succeeded': measurement.succeeded,
            'elapsedMilliseconds': measurement.elapsedMilliseconds,
          }
      ]
    };
    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }
    outFile.writeAsStringSync(json.encode(jsonData));
  }

  /// Update tizen-manifest.xml with the new build info if needed.
  static void updateManifest(TizenProject project, BuildInfo buildInfo) {
    final String buildName =
        buildInfo.buildName ?? project.parent.manifest.buildName;
    if (buildName == null) {
      return;
    }
    final TizenManifest manifest =
        TizenManifest.parseFromXml(project.manifestFile);
    manifest.version = buildName;
    project.manifestFile.writeAsStringSync(manifest.toString());
  }
}
