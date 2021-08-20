// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

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

class TizenCreateCommand extends CreateCommand {
  TizenCreateCommand({bool verboseHelp = false})
      : super(verboseHelp: verboseHelp) {
    argParser.addOption(
      'tizen-language',
      defaultsTo: 'csharp',
      allowed: <String>['cpp', 'csharp'],
    );
    argParser.addOption(
      'app-type',
      defaultsTo: 'ui',
      allowed: <String>['ui', 'service', 'multi'],
      help: 'Select a type of application template.',
    );
  }

  @override
  void printUsage() {
    super.printUsage();
    // TODO(swift-kim): I couldn't find a proper way to override the --platforms
    // option without copying the entire class. This message is a workaround.
    print(
      'You don\'t have to specify "tizen" as a target platform with '
      '"--platforms" option. It is automatically added by default.',
    );
  }

  /// See:
  /// - [CreateCommand.runCommand] in `create.dart`
  /// - [CreateCommand._getProjectType] in `create.dart` (generatePlugin)
  Future<FlutterCommandResult> runInternal() async {
    final FlutterCommandResult result = await super.runCommand();
    if (result != FlutterCommandResult.success() || argResults.rest.isEmpty) {
      return result;
    }

    final bool generatePlugin = argResults['template'] != null
        ? stringArg('template') ==
            flutterProjectTypeToString(FlutterProjectType.plugin)
        : determineTemplateType() == FlutterProjectType.plugin;
    if (generatePlugin) {
      // Assume that pubspec.yaml uses the multi-platforms plugin format if the
      // file already exists.
      // TODO(swift-kim): Skip this message if tizen already exists in pubspec.
      globals.printStatus(
        'The `pubspec.yaml` under the project directory must be updated to support Tizen.\n'
        'Add below lines to under the `platforms:` key.',
        emphasis: true,
        color: TerminalColor.yellow,
      );
      final Map<String, dynamic> templateContext = createTemplateContext(
        organization: '',
        projectName: projectName,
        flutterRoot: '',
      );
      globals.printStatus(
        '\ntizen:\n'
        '  pluginClass: ${templateContext['pluginClass'] as String}\n'
        '  fileName: ${projectName}_plugin.h',
        emphasis: true,
        color: TerminalColor.blue,
      );
      globals.printStatus('');
    }

    // TODO(pkosko): Find better solution for inject a multi-project main.dart file
    if (stringArg('app-type').compareTo('multi') == 0) {
      final File mainFile =
          projectDir.childDirectory('tizen').childFile('main.dart');
      mainFile.copySync(
          projectDir.childDirectory('lib').childFile('main.dart').path);
      mainFile.deleteSync();
    }

    return result;
  }

  /// See: [Template.render] in `template.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
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
    final File tizenTemplateManifest =
        tizenTemplates.childFile('template_manifest.json');

    final Directory templates = globals.fs
        .directory(Cache.flutterRoot)
        .childDirectory('packages')
        .childDirectory('flutter_tools')
        .childDirectory('templates');
    final File templateManifest = templates.childFile('template_manifest.json');

    // This is required due to: https://github.com/flutter/flutter/pull/59706
    // TODO(swift-kim): Find any better workaround. One option is to override
    // renderTemplate() but it may result in additional complexity.
    tizenTemplateManifest.copySync(templateManifest.path);

    final String appLanguage = stringArg('tizen-language');
    // The Dart plugin template is not currently supported.
    const String pluginLanguage = 'cpp';

    final List<Directory> created = <Directory>[];
    try {
      void copyTemplate(String source, String language, String destination) {
        final Directory sourceDir =
            tizenTemplates.childDirectory(source).childDirectory(language);
        if (!sourceDir.existsSync()) {
          throwToolExit('Could not locate a template: $source/$language');
        }
        final Directory destinationDir =
            templates.childDirectory(destination).childDirectory('tizen.tmpl');
        if (destinationDir.existsSync()) {
          destinationDir.deleteSync(recursive: true);
        }
        copyDirectory(sourceDir, destinationDir);
        created.add(destinationDir);
      }

      final String appType = stringArg('app-type');
      if (appType.compareTo('multi') == 0) {
        copyTemplate('multi-app', appLanguage, 'app');
      } else if (appType.compareTo('service') == 0) {
        copyTemplate('service-app', appLanguage, 'app');
      } else {
        copyTemplate('ui-app', appLanguage, 'app');
      }
      copyTemplate('plugin', pluginLanguage, 'plugin');

      return await runInternal();
    } finally {
      for (final Directory template in created) {
        template.deleteSync(recursive: true);
      }
    }
  }
}
