// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/commands/packages.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_plugins.dart';

/// Source: [PackagesCommand] in `packages.dart`
class TizenPackagesCommand extends PackagesCommand {
  TizenPackagesCommand({
    required super.buildSystem,
    required super.toolContext,
    super.verboseHelp,
  }) : _buildSystem = buildSystem;

  final BuildSystem _buildSystem;

  static final _pubContexts = <String, PubContext>{
    'get': PubContext.pubGet,
    'upgrade': PubContext.pubUpgrade,
    'add': PubContext.pubAdd,
    'remove': PubContext.pubRemove,
  };

  @override
  void addSubcommand(Command<void> command) {
    if (command is PackagesGetCommand) {
      command = TizenPackagesGetCommand(
        command,
        _pubContexts[command.name]!,
        buildSystem: _buildSystem,
        toolContext: toolContext!,
      );
    }
    super.addSubcommand(command);
  }
}

class TizenPackagesGetCommand extends PackagesGetCommand {
  TizenPackagesGetCommand(
    this._command,
    PubContext context, {
    required super.buildSystem,
    required super.toolContext,
  }) : super(_command.name, '', context);

  final PackagesGetCommand _command;

  @override
  String get description => _command.description;

  /// Source: [PackagesGetCommand._permissiveArgParser] in `packages.dart`
  static final ArgParser _permissiveArgParser = ArgParser()
    ..addOption('directory', abbr: 'C')
    ..addFlag('offline')
    ..addFlag('dry-run', abbr: 'n')
    ..addFlag('help', abbr: 'h')
    ..addFlag('enforce-lockfile')
    ..addFlag('precompile')
    ..addFlag('major-versions')
    ..addFlag('example', defaultsTo: true)
    ..addOption('sdk')
    ..addOption('path')
    ..addOption('hosted-url')
    ..addOption('git-url')
    ..addOption('git-ref')
    ..addOption('git-path')
    ..addFlag('dev')
    ..addFlag('verbose', abbr: 'v');

  /// See: [PackagesGetCommand.runCommand] in `packages.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    final FlutterCommandResult result = await super.runCommand();
    String? directoryOption;
    try {
      final ArgResults results = _permissiveArgParser.parse(argResults!.rest);
      if (results['help'] as bool) {
        return result;
      }
      directoryOption = results['directory'] as String?;
    } on ArgParserException {
      // Flutter falls back to the current directory as well.
    }
    final FileSystem fs = toolContext!.fs;
    final String? target = findProjectRoot(fs, directoryOption);
    if (target != null) {
      await ensureReadyForTizenTooling(
          toolContext!.projectFactory.fromDirectory(fs.directory(target)));
    }
    return result;
  }
}
