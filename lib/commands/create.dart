// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/create.dart';
import 'package:flutter_tools/src/flutter_project_metadata.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/template.dart';

const List<String> _kAvailablePlatforms = <String>[
  'tizen',
  'ios',
  'android',
  'windows',
  'linux',
  'macos',
  'web',
];

class TizenCreateCommand extends CreateCommand {
  TizenCreateCommand({bool verboseHelp = false})
      : super(verboseHelp: verboseHelp) {
    argParser.addOption(
      'tizen-language',
      defaultsTo: 'csharp',
      allowed: <String>['cpp', 'csharp'],
      help: 'The language to use for Tizen-specific code, either C++ '
          '(performant, but unsupported by TV devices) or C# (universal).',
    );
    argParser.addOption(
      'app-type',
      defaultsTo: 'ui',
      allowed: <String>['ui', 'service', 'multi'],
      help: 'Select a type of application template.',
    );
  }

  @override
  void addPlatformsOptions({String customHelp}) {
    argParser.addMultiOption(
      'platforms',
      help: customHelp,
      defaultsTo: _kAvailablePlatforms,
      allowed: _kAvailablePlatforms,
    );
  }

  @override
  Future<int> renderTemplate(
    String templateName,
    Directory directory,
    Map<String, Object> context, {
    bool overwrite = false,
  }) async {
    // Disables https://github.com/flutter/flutter/pull/59706 by setting
    // templateManifest to null.
    final Template template = await Template.fromName(
      templateName,
      fileSystem: globals.fs,
      logger: globals.logger,
      templateRenderer: globals.templateRenderer,
      templateManifest: null,
    );
    return template.render(directory, context, overwriteExisting: overwrite);
  }

  @override
  Future<int> renderMerged(
    List<String> names,
    Directory directory,
    Map<String, Object> context, {
    bool overwrite = false,
  }) async {
    // Disables https://github.com/flutter/flutter/pull/59706 by setting
    // templateManifest to null.
    final Template template = await Template.merged(
      names,
      directory,
      fileSystem: globals.fs,
      logger: globals.logger,
      templateRenderer: globals.templateRenderer,
      templateManifest: null,
    );
    return template.render(directory, context, overwriteExisting: overwrite);
  }

  /// See: [CreateCommand._getProjectType] in `create.dart`
  bool get _shouldGeneratePlugin {
    if (argResults['template'] != null) {
      return stringArg('template') == 'plugin';
    } else if (projectDir.existsSync() && projectDir.listSync().isNotEmpty) {
      return determineTemplateType() == FlutterProjectType.plugin;
    }
    return false;
  }

  /// See: [CreateCommand.runCommand] in `create.dart`
  Future<FlutterCommandResult> _runCommand() async {
    final FlutterCommandResult result = await super.runCommand();
    if (result != FlutterCommandResult.success()) {
      return result;
    }

    if (_shouldGeneratePlugin) {
      final String relativePluginPath =
          globals.fs.path.normalize(globals.fs.path.relative(projectDirPath));
      globals.printStatus(
        'Make sure your $relativePluginPath/pubspec.yaml contains the following lines.',
        color: TerminalColor.yellow,
      );
      final Map<String, Object> templateContext = createTemplateContext(
        organization: '',
        projectName: projectName,
        flutterRoot: '',
      );
      globals.printStatus(
        '\nflutter:\n'
        '  plugin:\n'
        '    platforms:\n'
        '      tizen:\n'
        '        pluginClass: ${templateContext['pluginClass'] as String}\n'
        '        fileName: ${projectName}_plugin.h',
        color: TerminalColor.blue,
      );
      globals.printStatus('');
    }

    return result;
  }

  /// See:
  /// - [CreateCommand._generatePlugin] in `create.dart`
  /// - [Template.render] in `template.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    if (argResults.rest.isEmpty) {
      return super.runCommand();
    }
    final List<String> platforms = stringsArg('platforms');
    bool shouldRenderTizenTemplate = platforms.contains('tizen');
    if (_shouldGeneratePlugin && !argResults.wasParsed('platforms')) {
      shouldRenderTizenTemplate = false;
    }
    if (!shouldRenderTizenTemplate) {
      return super.runCommand();
    }

    // The template directory that the flutter tools search for available
    // templates cannot be overriden because the implementation is private.
    // So we have to copy Tizen templates into the directory manually.
    final Directory tizenTemplates = globals.fs
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('templates');
    if (!tizenTemplates.existsSync()) {
      throwToolExit('Could not locate Tizen templates.');
    }
    final Directory templates = globals.fs
        .directory(Cache.flutterRoot)
        .childDirectory('packages')
        .childDirectory('flutter_tools')
        .childDirectory('templates');
    _runGitClean(templates);

    final String appLanguage = stringArg('tizen-language');
    final String appType = stringArg('app-type');
    final String template = stringArg('template');
    if (appType == 'multi' && template != null && template != 'app') {
      throwToolExit(
          '--app-type=$appType and --template=$template cannot be provided at the same time.');
    }

    try {
      void copyTemplate(String source, String language, String destination) {
        final Directory sourceDir = tizenTemplates.childDirectory(source);
        if (!sourceDir.childDirectory(language).existsSync()) {
          throwToolExit('Could not locate a template: $source/$language');
        }
        final Directory destinationDir = templates.childDirectory(destination);

        for (final FileSystemEntity entity in sourceDir.listSync()) {
          if (entity.basename == language) {
            copyDirectory(entity as Directory,
                destinationDir.childDirectory('tizen.tmpl'));
          } else if (entity.basename == 'lib') {
            copyDirectory(entity as Directory,
                destinationDir.childDirectory(entity.basename));
          } else if (entity is File) {
            entity.copySync(destinationDir.childFile(entity.basename).path);
          }
        }
      }

      copyTemplate('$appType-app', appLanguage, 'app_shared');
      copyTemplate('plugin', 'cpp', 'plugin');

      return await _runCommand();
    } finally {
      _runGitClean(templates);
    }
  }

  void _runGitClean(Directory directory) {
    ProcessResult result = globals.processManager.runSync(
      <String>['git', 'restore', '.'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to run git restore: $result');
    }
    result = globals.processManager.runSync(
      <String>['git', 'clean', '-df', '.'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to run git clean: $result');
    }
  }
}
