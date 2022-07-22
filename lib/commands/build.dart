// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/android/build_validation.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/commands/build.dart';
import 'package:flutter_tools/src/commands/build_apk.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_build_info.dart';
import '../tizen_builder.dart';
import '../tizen_cache.dart';
import '../tizen_plugins.dart';

class TizenBuildCommand extends BuildCommand {
  TizenBuildCommand({bool verboseHelp = false})
      : super(verboseHelp: verboseHelp) {
    addSubcommand(BuildTpkCommand(verboseHelp: verboseHelp));
    addSubcommand(BuildModuleCommand(verboseHelp: verboseHelp));
  }
}

class BuildTpkCommand extends BuildSubCommand
    with DartPluginRegistry, TizenRequiredArtifacts {
  /// See: [BuildApkCommand] in `build_apk.dart`
  BuildTpkCommand({required bool verboseHelp})
      : super(verboseHelp: verboseHelp) {
    addCommonDesktopBuildOptions(verboseHelp: verboseHelp);
    argParser.addOption(
      'target-arch',
      defaultsTo: 'arm',
      allowed: <String>['arm', 'arm64', 'x86'],
      help: 'The target architecture for which the the app is compiled.',
    );
    argParser.addOption(
      'device-profile',
      abbr: 'p',
      allowed: <String>['mobile', 'wearable', 'tv', 'common'],
      help: 'The type of device that the app will run on. Choose "wearable" '
          'for watch devices and "common" for IoT (Raspberry Pi) devices.',
    );
    argParser.addOption(
      'security-profile',
      abbr: 's',
      help: 'The name of security profile to sign the TPK with. (defaults to '
          'the current active profile)',
    );
  }

  @override
  final String name = 'tpk';

  @override
  final String description = 'Build a Tizen TPK file from your app.';

  /// See: [BuildApkCommand.runCommand] in `build_apk.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    final String? deviceProfile = stringArg('device-profile');
    if (deviceProfile == null) {
      throwToolExit(
          'The --device-profile (-p) option is mandatory. e.g. -pwearable, -ptv');
    }
    final BuildInfo buildInfo = await getBuildInfo();
    final TizenBuildInfo tizenBuildInfo = TizenBuildInfo(
      buildInfo,
      targetArch: stringArg('target-arch')!,
      deviceProfile: deviceProfile,
      securityProfile: stringArg('security-profile'),
    );
    _validateBuild(tizenBuildInfo);
    displayNullSafetyMode(buildInfo);

    await tizenBuilder?.buildTpk(
      project: FlutterProject.current(),
      targetFile: targetFile,
      tizenBuildInfo: tizenBuildInfo,
    );
    return FlutterCommandResult.success();
  }
}

class BuildModuleCommand extends BuildSubCommand
    with DartPluginRegistry, TizenRequiredArtifacts {
  BuildModuleCommand({required bool verboseHelp})
      : super(verboseHelp: verboseHelp) {
    addCommonDesktopBuildOptions(verboseHelp: verboseHelp);
    argParser.addOption(
      'target-arch',
      defaultsTo: 'arm',
      allowed: <String>['arm', 'arm64', 'x86'],
      help: 'The target architecture for which the the app is compiled.',
    );
    argParser.addOption(
      'device-profile',
      abbr: 'p',
      allowed: <String>['mobile', 'wearable', 'tv', 'common'],
      help: 'The type of device that the app will run on. Choose "wearable" '
          'for watch devices and "common" for IoT (Raspberry Pi) devices.',
    );
    // TODO: --output-dir
  }

  @override
  final String name = 'module';

  @override
  final String description =
      'Build a module that can be embedded in your existing Tizen native app.';

  @override
  Future<FlutterCommandResult> runCommand() async {
    final String? deviceProfile = stringArg('device-profile');
    if (deviceProfile == null) {
      // TODO(swift-kim): Consider relieving this limitation.
      throwToolExit(
          'The --device-profile (-p) option is mandatory. e.g. -pwearable, -ptv');
    }
    final BuildInfo buildInfo = await getBuildInfo();
    final TizenBuildInfo tizenBuildInfo = TizenBuildInfo(
      buildInfo,
      targetArch: stringArg('target-arch')!,
      deviceProfile: deviceProfile,
    );
    _validateBuild(tizenBuildInfo);
    displayNullSafetyMode(buildInfo);

    await tizenBuilder?.buildModule(
      project: FlutterProject.current(),
      targetFile: targetFile,
      tizenBuildInfo: tizenBuildInfo,
    );
    return FlutterCommandResult.success();
  }
}

/// See: [validateBuild] in `build_validation.dart`
void _validateBuild(TizenBuildInfo tizenBuildInfo) {
  if (tizenBuildInfo.buildInfo.mode.isPrecompiled &&
      tizenBuildInfo.targetArch == 'x86') {
    throwToolExit('x86 ABI does not support AOT compilation.');
  }
}
