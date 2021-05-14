// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_tools/executable.dart' as flutter;
import 'package:flutter_tools/runner.dart' as runner;
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/config.dart';
import 'package:flutter_tools/src/commands/devices.dart';
import 'package:flutter_tools/src/commands/emulators.dart';
import 'package:flutter_tools/src/commands/doctor.dart';
import 'package:flutter_tools/src/commands/format.dart';
import 'package:flutter_tools/src/commands/generate_localizations.dart';
import 'package:flutter_tools/src/commands/install.dart';
import 'package:flutter_tools/src/commands/logs.dart';
import 'package:flutter_tools/src/commands/screenshot.dart';
import 'package:flutter_tools/src/commands/symbolize.dart';
import 'package:flutter_tools/src/emulator.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/version.dart';
import 'package:path/path.dart';

import 'commands/analyze.dart';
import 'commands/attach.dart';
import 'commands/build.dart';
import 'commands/clean.dart';
import 'commands/create.dart';
import 'commands/drive.dart';
import 'commands/packages.dart';
import 'commands/run.dart';
import 'commands/test.dart';
import 'tizen_artifacts.dart';
import 'tizen_device_discovery.dart';
import 'tizen_doctor.dart';
import 'tizen_emulator.dart';
import 'tizen_sdk.dart';
import 'tizen_tpk.dart';

/// Main entry point for commands.
///
/// Source: [flutter.main] in `executable.dart` (some commands and options were omitted)
Future<void> main(List<String> args) async {
  final bool veryVerbose = args.contains('-vv');
  final bool verbose =
      args.contains('-v') || args.contains('--verbose') || veryVerbose;

  final bool doctor = (args.isNotEmpty && args.first == 'doctor') ||
      (args.length == 2 && verbose && args.last == 'doctor');
  final bool help = args.contains('-h') ||
      args.contains('--help') ||
      (args.isNotEmpty && args.first == 'help') ||
      (args.length == 1 && verbose);
  final bool muteCommandLogging = (help || doctor) && !veryVerbose;
  final bool verboseHelp = help && verbose;

  final bool hasSpecifiedDeviceId =
      args.contains('-d') || args.contains('--device-id');

  args = <String>[
    '--suppress-analytics', // Suppress flutter analytics by default.
    '--no-version-check',
    if (!hasSpecifiedDeviceId) ...<String>['--device-id', 'tizen'],
    ...args,
  ];

  Cache.flutterRoot = flutterRoot;

  await runner.run(
    args,
    () => <FlutterCommand>[
      // Commands directly from flutter_tools.
      ConfigCommand(verboseHelp: verboseHelp),
      DevicesCommand(),
      DoctorCommand(verbose: verbose),
      EmulatorsCommand(),
      FormatCommand(),
      GenerateLocalizationsCommand(
        fileSystem: globals.fs,
        logger: globals.logger,
      ),
      InstallCommand(),
      LogsCommand(),
      ScreenshotCommand(),
      SymbolizeCommand(stdio: globals.stdio, fileSystem: globals.fs),
      // Commands extended for Tizen.
      TizenAnalyzeCommand(verboseHelp: verboseHelp),
      TizenAttachCommand(verboseHelp: verboseHelp),
      TizenBuildCommand(verboseHelp: verboseHelp),
      TizenCleanCommand(verbose: verbose),
      TizenCreateCommand(),
      TizenDriveCommand(verboseHelp: verboseHelp),
      TizenPackagesCommand(),
      TizenRunCommand(verboseHelp: verboseHelp),
      TizenTestCommand(verboseHelp: verboseHelp),
    ],
    verbose: verbose,
    verboseHelp: verboseHelp,
    muteCommandLogging: muteCommandLogging,
    reportCrashes: false,
    overrides: <Type, Generator>{
      ApplicationPackageFactory: () => TpkFactory(),
      DeviceManager: () => TizenDeviceManager(),
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      DoctorValidatorsProvider: () => TizenDoctorValidatorsProvider(),
      TizenSdk: () => TizenSdk.locateSdk(),
      TizenArtifacts: () => TizenArtifacts(),
      TizenWorkflow: () => TizenWorkflow(),
      TizenValidator: () => TizenValidator(),
      EmulatorManager: () => TizenEmulatorManager(
            tizenSdk: tizenSdk,
            tizenWorkflow: tizenWorkflow,
            processManager: globals.processManager,
            logger: globals.logger,
            fileSystem: globals.fs,
          ),
      FlutterVersion: () => _FlutterVersion(),
      if (verbose && !muteCommandLogging)
        Logger: () => VerboseLogger(StdoutLogger(
              stdio: globals.stdio,
              terminal: globals.terminal,
              outputPreferences: globals.outputPreferences,
              stopwatchFactory: const StopwatchFactory(),
            )),
    },
  );
}

/// See: [Cache.defaultFlutterRoot] in `cache.dart`
String get flutterRoot {
  final String scriptPath = Platform.script.toFilePath();
  final String rootPath = normalize(join(
    scriptPath,
    scriptPath.endsWith('.snapshot') ? '../../..' : '../..',
  ));
  return join(rootPath, 'flutter');
}

class _FlutterVersion extends FlutterVersion {
  _FlutterVersion();

  String get flutterTizenRevisionShort =>
      _runGitLog(<String>['-n', '1', '--pretty=format:%H']).substring(0, 10);

  String get flutterTizenAge =>
      _runGitLog(<String>['-n', '1', '--pretty=format:%ar']);

  String _runGitLog(List<String> args) => globals.processUtils.runSync(
        <String>['git', '-c', 'log.showSignature=false', 'log', ...args],
        workingDirectory: dirname(Cache.flutterRoot),
      ).stdout;

  /// Source: [FlutterVersion.toString] in `version.dart`
  @override
  String toString() {
    final String versionText =
        frameworkVersion == 'unknown' ? '' : ' $frameworkVersion';
    final String flutterText =
        'Flutter for Tizen$versionText • revision $flutterTizenRevisionShort ($flutterTizenAge)';
    final String frameworkText =
        'Framework • revision $frameworkRevisionShort ($frameworkAge) • $frameworkCommitDate';
    final String engineText = 'Engine • revision $engineRevisionShort';
    final String toolsText = 'Tools • Dart $dartSdkVersion';

    return '$flutterText\n$frameworkText\n$engineText\n$toolsText';
  }
}
