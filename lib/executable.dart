// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:flutter_tools/executable.dart' as flutter show main;
import 'package:flutter_tools/executable.dart';
import 'package:flutter_tools/runner.dart' as runner;
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/analyze.dart';
import 'package:flutter_tools/src/commands/config.dart';
import 'package:flutter_tools/src/commands/daemon.dart';
import 'package:flutter_tools/src/commands/devices.dart';
import 'package:flutter_tools/src/commands/doctor.dart';
import 'package:flutter_tools/src/commands/emulators.dart';
import 'package:flutter_tools/src/commands/format.dart';
import 'package:flutter_tools/src/commands/generate_localizations.dart';
import 'package:flutter_tools/src/commands/install.dart';
import 'package:flutter_tools/src/commands/packages.dart';
import 'package:flutter_tools/src/commands/screenshot.dart';
import 'package:flutter_tools/src/commands/symbolize.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/emulator.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:path/path.dart';

import 'commands/attach.dart';
import 'commands/build.dart';
import 'commands/clean.dart';
import 'commands/create.dart';
import 'commands/drive.dart';
import 'commands/precache.dart';
import 'commands/run.dart';
import 'commands/test.dart';
import 'tizen_application_package.dart';
import 'tizen_artifacts.dart';
import 'tizen_build_system.dart';
import 'tizen_builder.dart';
import 'tizen_cache.dart';
import 'tizen_device_manager.dart';
import 'tizen_doctor.dart';
import 'tizen_emulator.dart';
import 'tizen_osutils.dart';
import 'tizen_pub.dart';
import 'tizen_sdk.dart';

/// Main entry point for commands.
///
/// Source: [flutter.main] in `executable.dart` (some commands and options were omitted)
Future<void> main(List<String> args) async {
  final bool veryVerbose = args.contains('-vv');
  final bool verbose =
      args.contains('-v') || args.contains('--verbose') || veryVerbose;
  final bool prefixedErrors = args.contains('--prefixed-errors');

  final bool doctor = (args.isNotEmpty && args.first == 'doctor') ||
      (args.length == 2 && verbose && args.last == 'doctor');
  final bool help = args.contains('-h') ||
      args.contains('--help') ||
      (args.isNotEmpty && args.first == 'help') ||
      (args.length == 1 && verbose);
  final bool muteCommandLogging = (help || doctor) && !veryVerbose;
  final bool verboseHelp = help && verbose;
  final bool daemon = args.contains('daemon');
  final bool runMachine = args.contains('--machine') && args.contains('run');

  final bool hasSpecifiedDeviceId =
      args.contains('-d') || args.contains('--device-id');

  args = <String>[
    '--suppress-analytics', // Suppress flutter analytics by default.
    '--no-version-check',
    if (!hasSpecifiedDeviceId) ...<String>['--device-id', 'tizen'],
    ...args,
  ];

  Cache.flutterRoot = join(rootPath, 'flutter');

  await runner.run(
    args,
    () => <FlutterCommand>[
      // Commands directly from flutter_tools.
      AnalyzeCommand(
        verboseHelp: verboseHelp,
        fileSystem: globals.fs,
        platform: globals.platform,
        terminal: globals.terminal,
        logger: globals.logger,
        processManager: globals.processManager,
        artifacts: globals.artifacts,
      ),
      ConfigCommand(verboseHelp: verboseHelp),
      DaemonCommand(hidden: !verboseHelp),
      DevicesCommand(verboseHelp: verboseHelp),
      DoctorCommand(verbose: verbose),
      EmulatorsCommand(),
      FormatCommand(verboseHelp: verboseHelp),
      GenerateLocalizationsCommand(
        fileSystem: globals.fs,
        logger: globals.logger,
      ),
      InstallCommand(),
      PackagesCommand(),
      ScreenshotCommand(),
      SymbolizeCommand(stdio: globals.stdio, fileSystem: globals.fs),
      // Commands extended for Tizen.
      TizenAttachCommand(verboseHelp: verboseHelp),
      TizenBuildCommand(verboseHelp: verboseHelp),
      TizenCleanCommand(verbose: verbose),
      TizenCreateCommand(verboseHelp: verboseHelp),
      TizenDriveCommand(
        verboseHelp: verboseHelp,
        fileSystem: globals.fs,
        logger: globals.logger,
        platform: globals.platform,
      ),
      TizenPrecacheCommand(
        verboseHelp: verboseHelp,
        cache: globals.cache,
        logger: globals.logger,
        platform: globals.platform,
        featureFlags: featureFlags,
      ),
      TizenRunCommand(verboseHelp: verboseHelp),
      TizenTestCommand(verboseHelp: verboseHelp),
    ],
    verbose: verbose,
    verboseHelp: verboseHelp,
    muteCommandLogging: muteCommandLogging,
    reportCrashes: false,
    overrides: <Type, Generator>{
      ApplicationPackageFactory: () => TizenApplicationPackageFactory(
            androidSdk: globals.androidSdk,
            processManager: globals.processManager,
            logger: globals.logger,
            userMessages: globals.userMessages,
            fileSystem: globals.fs,
          ),
      Artifacts: () => TizenArtifacts(
            fileSystem: globals.fs,
            cache: globals.cache,
            platform: globals.platform,
            operatingSystemUtils: globals.os,
          ),
      BuildSystem: () => TizenBuildSystem(
            fileSystem: globals.fs,
            platform: globals.platform,
            logger: globals.logger,
          ),
      Cache: () => TizenFlutterCache(
            fileSystem: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
            osUtils: globals.os,
            processManager: globals.processManager,
          ),
      DeviceManager: () => TizenDeviceManager(),
      DoctorValidatorsProvider: () => TizenDoctorValidatorsProvider(),
      EmulatorManager: () => TizenEmulatorManager(
            tizenSdk: tizenSdk,
            tizenWorkflow: tizenWorkflow,
            fileSystem: globals.fs,
            logger: globals.logger,
            processManager: globals.processManager,
          ),
      Logger: () {
        final LoggerFactory loggerFactory = LoggerFactory(
          outputPreferences: globals.outputPreferences,
          terminal: globals.terminal,
          stdio: globals.stdio,
        );
        return loggerFactory.createLogger(
          daemon: daemon,
          machine: runMachine,
          verbose: verbose && !muteCommandLogging,
          prefixedErrors: prefixedErrors,
          windows: globals.platform.isWindows,
        );
      },
      OperatingSystemUtils: () => TizenOperatingSystemUtils(
            fileSystem: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
            processManager: globals.processManager,
          ),
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      TizenBuilder: () => TizenBuilder(),
      TizenSdk: () => TizenSdk.locateSdk(),
      TizenValidator: () => TizenValidator(
            tizenSdk: tizenSdk,
            dotnetCli: dotnetCli,
            fileSystem: globals.fs,
            logger: globals.logger,
            processManager: globals.processManager,
            userMessages: globals.userMessages,
          ),
      TizenWorkflow: () => TizenWorkflow(
            tizenSdk: tizenSdk,
            operatingSystemUtils: globals.os,
          ),
      Pub: () => TizenPub(
            fileSystem: globals.fs,
            logger: globals.logger,
            processManager: globals.processManager,
            platform: globals.platform,
            botDetector: globals.botDetector,
            usage: globals.flutterUsage,
          ),
    },
  );
}

/// See: [Cache.defaultFlutterRoot] in `cache.dart`
String get rootPath {
  final String scriptPath = Platform.script.toFilePath();
  return normalize(join(
    scriptPath,
    scriptPath.endsWith('.snapshot') ? '../../..' : '../..',
  ));
}
