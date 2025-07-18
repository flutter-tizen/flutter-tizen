// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/android/build_validation.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
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
  TizenBuildCommand({
    required super.fileSystem,
    required super.buildSystem,
    required super.osUtils,
    required Logger logger,
    required super.androidSdk,
    bool verboseHelp = false,
  }) : super(logger: logger, verboseHelp: verboseHelp) {
    addSubcommand(BuildTpkCommand(logger: logger, verboseHelp: verboseHelp));
    addSubcommand(BuildModuleCommand(logger: logger, verboseHelp: verboseHelp));
  }
}

class BuildTpkCommand extends BuildSubCommand with DartPluginRegistry, TizenRequiredArtifacts {
  /// See: [BuildApkCommand] in `build_apk.dart`
  BuildTpkCommand({
    required super.logger,
    required bool verboseHelp,
  }) : super(verboseHelp: verboseHelp) {
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
      defaultsTo: 'tv',
      allowed: <String>['mobile', 'tv', 'common'],
      help:
          'The type of device that the app will run on. Choose "common" for the unified Tizen profile.',
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
    final BuildInfo buildInfo = await getBuildInfo();
    final TizenBuildInfo tizenBuildInfo = TizenBuildInfo(
      buildInfo,
      targetArch: stringArg('target-arch')!,
      deviceProfile: stringArg('device-profile')!,
      securityProfile: stringArg('security-profile'),
    );
    _validateBuild(tizenBuildInfo);

    await tizenBuilder?.buildTpk(
      project: FlutterProject.current(),
      targetFile: targetFile,
      tizenBuildInfo: tizenBuildInfo,
    );
    return FlutterCommandResult.success();
  }
}

class BuildModuleCommand extends BuildSubCommand with DartPluginRegistry, TizenRequiredArtifacts {
  BuildModuleCommand({
    required super.logger,
    required bool verboseHelp,
  }) : super(verboseHelp: verboseHelp) {
    addBuildModeFlags(verboseHelp: verboseHelp);
    addDartObfuscationOption();
    addEnableExperimentation(hide: !verboseHelp);
    addSplitDebugInfoOption();
    addTreeShakeIconsFlag();
    usesDartDefineOption();
    usesExtraDartFlagOptions(verboseHelp: verboseHelp);
    usesPubOption();
    usesTargetOption();
    usesTrackWidgetCreation(verboseHelp: verboseHelp);
    argParser.addOption(
      'target-arch',
      defaultsTo: 'arm',
      allowed: <String>['arm', 'arm64', 'x86'],
      help: 'The target architecture for which the the app is compiled.',
    );
    argParser.addOption(
      'device-profile',
      abbr: 'p',
      defaultsTo: 'tv',
      allowed: <String>['mobile', 'tv', 'common'],
      help: 'The type of device that the app will run on.',
    );
    argParser.addOption(
      'output-dir',
      help: 'The absolute path to the directory where the files are generated. '
          'By default, this is "<current-directory>/build/tizen/module".',
    );
  }

  @override
  final String name = 'module';

  @override
  final String description = 'Build a module that can be embedded in your existing Tizen app.';

  @override
  Future<FlutterCommandResult> runCommand() async {
    final BuildInfo buildInfo = await getBuildInfo();
    final TizenBuildInfo tizenBuildInfo = TizenBuildInfo(
      buildInfo,
      targetArch: stringArg('target-arch')!,
      deviceProfile: stringArg('device-profile')!,
    );
    _validateBuild(tizenBuildInfo);

    await tizenBuilder?.buildModule(
      project: FlutterProject.current(),
      targetFile: targetFile,
      tizenBuildInfo: tizenBuildInfo,
      outputDirectory: stringArg('output-dir'),
    );
    return FlutterCommandResult.success();
  }
}

/// See: [validateBuild] in `build_validation.dart`
void _validateBuild(TizenBuildInfo tizenBuildInfo) {
  if (tizenBuildInfo.buildInfo.mode.isPrecompiled && tizenBuildInfo.targetArch == 'x86') {
    throwToolExit('x86 ABI does not support AOT compilation.');
  }
  if (tizenBuildInfo.deviceProfile != 'common' && tizenBuildInfo.targetArch == 'arm64') {
    throwToolExit(
        'The arm64 build is not supported by the ${tizenBuildInfo.deviceProfile} profile.');
  }
}
