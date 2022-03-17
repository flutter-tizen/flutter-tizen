// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/targets/dart_plugin_registrant.dart';

class TizenBuildSystem extends BuildSystem {
  TizenBuildSystem({
    required FileSystem fileSystem,
    required Platform platform,
    required Logger logger,
  }) : _buildSystem = FlutterBuildSystem(
            fileSystem: fileSystem, platform: platform, logger: logger);

  final FlutterBuildSystem _buildSystem;

  @override
  Future<BuildResult> build(
    Target target,
    Environment environment, {
    BuildSystemConfig buildSystemConfig = const BuildSystemConfig(),
  }) {
    return _buildSystem.build(
      target,
      environment,
      buildSystemConfig: buildSystemConfig,
    );
  }

  @override
  Future<BuildResult> buildIncremental(
    Target target,
    Environment environment,
    BuildResult? previousBuild,
  ) {
    // Prevent regeneration of a Dart plugin registrant.
    // Note that this will break incremental build of applications that use
    // Dart plugins on desktop platforms.
    // Issue: https://github.com/flutter-tizen/plugins/issues/341
    if (target is CompositeTarget) {
      target = CompositeTarget(target.dependencies
          .where((Target target) => target is! DartPluginRegistrantTarget)
          .toList());
    }
    return _buildSystem.buildIncremental(target, environment, previousBuild);
  }
}
