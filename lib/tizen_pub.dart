// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/bot_detector.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/reporting/reporting.dart';
import 'package:process/process.dart';

import 'tizen_plugins.dart';

class TizenPub implements Pub {
  TizenPub({
    required FileSystem fileSystem,
    required Logger logger,
    required ProcessManager processManager,
    required Platform platform,
    required BotDetector botDetector,
    required Usage usage,
  })  : _fileSystem = fileSystem,
        _pub = Pub(
          fileSystem: fileSystem,
          logger: logger,
          processManager: processManager,
          platform: platform,
          botDetector: botDetector,
          usage: usage,
        );

  final FileSystem _fileSystem;
  final Pub _pub;

  @override
  Future<void> batch(
    List<String> arguments, {
    required PubContext context,
    String? directory,
    MessageFilter? filter,
    String failureMessage = 'pub failed',
  }) {
    return _pub.batch(
      arguments,
      context: context,
      directory: directory,
      filter: filter,
      failureMessage: failureMessage,
    );
  }

  @override
  Future<void> get({
    required PubContext context,
    required FlutterProject project,
    bool skipIfAbsent = false,
    bool upgrade = false,
    bool offline = false,
    String? flutterRootOverride,
    bool checkUpToDate = false,
    bool shouldSkipThirdPartyGenerator = true,
    bool printProgress = true,
  }) async {
    await _pub.get(
      context: context,
      project: project,
      skipIfAbsent: skipIfAbsent,
      upgrade: upgrade,
      offline: offline,
      flutterRootOverride: flutterRootOverride,
      checkUpToDate: checkUpToDate,
      shouldSkipThirdPartyGenerator: shouldSkipThirdPartyGenerator,
      printProgress: printProgress,
    );
    await _postPub(project);
  }

  @override
  Future<void> interactively(
    List<String> arguments, {
    String? directory,
    required Stdio stdio,
    bool touchesPackageConfig = false,
    bool generateSyntheticPackage = false,
  }) async {
    await _pub.interactively(
      arguments,
      directory: directory,
      stdio: stdio,
      touchesPackageConfig: touchesPackageConfig,
      generateSyntheticPackage: generateSyntheticPackage,
    );
    final FlutterProject project = directory == null
        ? FlutterProject.current()
        : FlutterProject.fromDirectory(_fileSystem.directory(directory));
    await _postPub(project);
  }

  /// A hack which enables Tizen plugin injection based on the fact that either
  /// [Pub.get] or [Pub.interactively] is always called before
  /// [FlutterProject.ensureReadyForPlatformSpecificTooling] is called.
  Future<void> _postPub(FlutterProject project) async {
    return ensureReadyForTizenTooling(project);
  }
}
