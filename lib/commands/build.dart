// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/android/build_validation.dart' as android;
import 'package:flutter_tools/src/base/analyze_size.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/commands/build.dart';
import 'package:flutter_tools/src/commands/build_apk.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_builder.dart';
import '../tizen_plugins.dart';

class TizenBuildCommand extends BuildCommand {
  TizenBuildCommand({bool verboseHelp = false})
      : super(verboseHelp: verboseHelp) {
    addSubcommand(BuildTpkCommand(verboseHelp: verboseHelp));
  }
}

class BuildTpkCommand extends BuildSubCommand with TizenExtension {
  /// See: [BuildApkCommand] in `build_apk.dart`
  BuildTpkCommand({bool verboseHelp = false}) {
    addCommonDesktopBuildOptions(verboseHelp: verboseHelp);
    usesBuildNameOption();
    argParser.addMultiOption(
      'target-arch',
      splitCommas: true,
      defaultsTo: <String>['arm'],
      allowed: <String>['arm', 'aarch64', 'x86'],
      help: 'The target architectures to compile the application for',
    );
    argParser.addOption(
      'security-profile',
      abbr: 's',
      help: 'The security profile name to sign the TPK with (defaults to the '
          'current active profile)',
    );
  }

  @override
  final String name = 'tpk';

  @override
  final String description = 'Build a Tizen TPK file from your app.';

  /// See: [android.validateBuild] in `build_validation.dart`
  void validateBuild(TizenBuildInfo tizenBuildInfo) {
    if (tizenBuildInfo.targetArchs.contains('aarch64')) {
      throwToolExit('Not supported arch: aarch64');
    }
    if (tizenBuildInfo.buildInfo.codeSizeDirectory != null &&
        tizenBuildInfo.targetArchs.length > 1) {
      throwToolExit(
          'Cannot perform code size analysis when building for multiple ABIs.');
    }
    if (tizenBuildInfo.buildInfo.mode.isPrecompiled &&
        tizenBuildInfo.targetArchs.contains('x86')) {
      throwToolExit('x86 ABI does not support AOT compilation.');
    }
  }

  /// See: [BuildApkCommand.runCommand] in `build_apk.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    final BuildInfo buildInfo = getBuildInfo();
    final TizenBuildInfo tizenBuildInfo = TizenBuildInfo(
      buildInfo,
      targetArchs: stringsArg('target-arch'),
      securityProfile: stringArg('security-profile'),
    );
    validateBuild(tizenBuildInfo);

    await TizenBuilder.buildTpk(
      tizenBuildInfo: tizenBuildInfo,
      project: FlutterProject.current(),
      targetFile: targetFile,
      sizeAnalyzer: SizeAnalyzer(
        fileSystem: globals.fs,
        logger: globals.logger,
        flutterUsage: globals.flutterUsage,
      ),
    );
    return FlutterCommandResult.success();
  }
}
