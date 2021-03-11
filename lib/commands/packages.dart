// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/commands/packages.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_plugins.dart';

/// This class is a direct copy of [PackagesCommand]. The only reason for the
/// duplication is to extend and replace [PackagesGetCommand] sub-commands in
/// the constructor. We may find a better workaround in the future.
///
/// Source: [PackagesCommand] in `packages.dart`
class TizenPackagesCommand extends FlutterCommand {
  TizenPackagesCommand() {
    addSubcommand(TizenPackagesGetCommand('get', false));
    addSubcommand(PackagesInteractiveGetCommand('upgrade',
        'Upgrade the current package\'s dependencies to latest versions.'));
    addSubcommand(PackagesInteractiveGetCommand(
        'add', 'Add a dependency to pubspec.yaml.'));
    addSubcommand(PackagesInteractiveGetCommand(
        'remove', 'Removes a dependency from the current package.'));
    addSubcommand(PackagesTestCommand());
    addSubcommand(PackagesForwardCommand(
        'publish', 'Publish the current package to pub.dartlang.org',
        requiresPubspec: true));
    addSubcommand(PackagesForwardCommand(
        'downgrade', 'Downgrade packages in a Flutter project',
        requiresPubspec: true));
    addSubcommand(PackagesForwardCommand('deps', 'Print package dependencies',
        requiresPubspec: true));
    addSubcommand(PackagesForwardCommand(
        'run', 'Run an executable from a package',
        requiresPubspec: true));
    addSubcommand(
        PackagesForwardCommand('cache', 'Work with the Pub system cache'));
    addSubcommand(PackagesForwardCommand('version', 'Print Pub version'));
    addSubcommand(PackagesForwardCommand(
        'uploader', 'Manage uploaders for a package on pub.dev'));
    addSubcommand(PackagesForwardCommand('login', 'Log into pub.dev.'));
    addSubcommand(PackagesForwardCommand('logout', 'Log out of pub.dev.'));
    addSubcommand(
        PackagesForwardCommand('global', 'Work with Pub global packages'));
    addSubcommand(PackagesForwardCommand(
        'outdated', 'Analyze dependencies to find which ones can be upgraded',
        requiresPubspec: true));
    addSubcommand(PackagesPassthroughCommand());
  }

  @override
  final String name = 'pub';

  @override
  List<String> get aliases => const <String>['packages'];

  @override
  final String description = 'Commands for managing Flutter packages.';

  @override
  Future<FlutterCommandResult> runCommand() async => null;
}

class TizenPackagesGetCommand extends PackagesGetCommand {
  TizenPackagesGetCommand(String name, bool upgrade) : super(name, upgrade);

  /// See: [PackagesGetCommand.runCommand] in `packages.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    final FlutterCommandResult result = await super.runCommand();

    // The super method runs [ensureReadyForPlatformSpecificTooling] for the
    // current project (and example project if found). We have to override it
    // for Tizen.
    if (result == FlutterCommandResult.success()) {
      final String workingDirectory =
          argResults.rest.isNotEmpty ? argResults.rest[0] : null;
      final String target = findProjectRoot(workingDirectory);
      if (target == null) {
        return result;
      }
      final FlutterProject rootProject = FlutterProject.fromPath(target);
      await injectTizenPlugins(rootProject);
      if (rootProject.hasExampleApp) {
        await injectTizenPlugins(rootProject.example);
      }
    }

    return result;
  }
}
