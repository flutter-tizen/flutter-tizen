// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/android/build_validation.dart' as android;
import 'package:flutter_tools/src/base/analyze_size.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/terminal.dart';
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
      allowed: <String>['arm', 'arm64', 'x86'],
      help: 'Target architectures to compile the application for',
    );
    argParser.addOption(
      'device-profile',
      allowed: <String>['mobile', 'wearable', 'tv', 'common'],
      help: 'Target device type that the app will run on. Choose \'wearable\' '
          'for watches and \'common\' for IoT (Raspberry Pi) devices.',
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
    String deviceProfile = stringArg('device-profile');
    if (deviceProfile == null) {
      globals.printStatus(
        'The "--device-profile" option is not set. Specify the target profile '
        'for which you want to build your app.',
        color: TerminalColor.yellow,
      );
      deviceProfile = 'common';
    }
    final BuildInfo buildInfo = await getBuildInfo();
    final TizenBuildInfo tizenBuildInfo = TizenBuildInfo(
      buildInfo,
      targetArchs: stringsArg('target-arch'),
      deviceProfile: deviceProfile,
      securityProfile: stringArg('security-profile'),
    );
    validateBuild(tizenBuildInfo);
    displayNullSafetyMode(buildInfo);

    await TizenBuilder.buildTpk(
      project: FlutterProject.current(),
      targetFile: targetFile,
      tizenBuildInfo: tizenBuildInfo,
      sizeAnalyzer: SizeAnalyzer(
        fileSystem: globals.fs,
        logger: globals.logger,
        flutterUsage: globals.flutterUsage,
      ),
    );
    return FlutterCommandResult.success();
  }
}
