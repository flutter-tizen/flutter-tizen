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
import 'package:flutter_tools/src/build_runner/mustache_template.dart';
import 'package:flutter_tools/src/commands/config.dart';
import 'package:flutter_tools/src/commands/devices.dart';
import 'package:flutter_tools/src/commands/emulators.dart';
import 'package:flutter_tools/src/commands/doctor.dart';
import 'package:flutter_tools/src/commands/format.dart';
import 'package:flutter_tools/src/commands/logs.dart';
import 'package:flutter_tools/src/commands/screenshot.dart';
import 'package:flutter_tools/src/emulator.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:path/path.dart';

import 'commands/analyze.dart';
import 'commands/attach.dart';
import 'commands/build.dart';
import 'commands/clean.dart';
import 'commands/create.dart';
import 'commands/drive.dart';
import 'commands/install.dart';
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
  final bool hasSpecifiedFlutterRoot = args.contains('--flutter-root');
  final String flutterRoot =
      normalize(join(Platform.script.toFilePath(), '../../flutter'));

  args = <String>[
    '--suppress-analytics', // Suppress flutter analytics by default.
    '--no-version-check',
    if (!hasSpecifiedFlutterRoot) ...<String>['--flutter-root', flutterRoot],
    if (!hasSpecifiedDeviceId) ...<String>['--device-id', 'tizen'],
    ...args,
  ];

  await runner.run(
    args,
    () => <FlutterCommand>[
      // Commands directly from flutter_tools.
      ConfigCommand(verboseHelp: verboseHelp),
      DevicesCommand(),
      DoctorCommand(verbose: verbose),
      EmulatorsCommand(),
      FormatCommand(),
      LogsCommand(),
      ScreenshotCommand(),
      // Commands extended for Tizen.
      TizenAnalyzeCommand(verboseHelp: verboseHelp),
      TizenAttachCommand(verboseHelp: verboseHelp),
      TizenBuildCommand(verboseHelp: verboseHelp),
      TizenCleanCommand(verbose: verbose),
      TizenCreateCommand(),
      TizenDriveCommand(),
      TizenInstallCommand(),
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
      if (verbose && !muteCommandLogging)
        Logger: () => VerboseLogger(StdoutLogger(
              timeoutConfiguration: timeoutConfiguration,
              stdio: globals.stdio,
              terminal: globals.terminal,
              outputPreferences: globals.outputPreferences,
            ))
    },
  );
}
