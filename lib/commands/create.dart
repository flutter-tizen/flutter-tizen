// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/create.dart';
import 'package:flutter_tools/src/flutter_project_metadata.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/template.dart';

import '../tizen_plugins.dart';

class TizenCreateCommand extends CreateCommand {
  TizenCreateCommand() : super() {
    argParser.addOption(
      'tizen-language',
      defaultsTo: 'csharp',
      allowed: <String>['cpp', 'csharp'],
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
        ? stringArg('template') == FlutterProjectType.plugin.name
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

    // Actually [super.runCommand] runs [ensureReadyForPlatformSpecificTooling]
    // based on the target project type. The following code doesn't check the
    // project type for simplicity. Revisit if this makes any problem.
    if (boolArg('pub')) {
      final FlutterProject project = FlutterProject.fromDirectory(projectDir);
      await injectTizenPlugins(project);
      if (project.hasExampleApp) {
        await injectTizenPlugins(project.example);
      }
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
    final File backupTemplateManifest =
        templates.childFile('template_manifest.json.bak');

    // This is required due to: https://github.com/flutter/flutter/pull/59706
    // TODO(swift-kim): Find any better workaround. One option is to override
    // renderTemplate() but it may result in additional complexity.
    if (templateManifest.existsSync() && !backupTemplateManifest.existsSync()) {
      templateManifest.renameSync(backupTemplateManifest.path);
      tizenTemplateManifest.copySync(templateManifest.path);
    }

    final String language = stringArg('tizen-language');
    if (language == 'cpp') {
      globals.printStatus(
        'Warning: The Tizen language option is experimental. Use it for testing purposes only.',
        color: TerminalColor.yellow,
      );
    }
    // The dart plugin template is not supported at the moment.
    const String pluginType = 'cpp';
    final List<Directory> created = <Directory>[];
    try {
      for (final Directory projectType
          in tizenTemplates.listSync().whereType<Directory>()) {
        final Directory source = projectType.childDirectory(
            projectType.basename == 'plugin' ? pluginType : language);
        if (!source.existsSync()) {
          continue;
        }
        final Directory dest = templates
            .childDirectory(projectType.basename)
            .childDirectory('tizen.tmpl');
        if (dest.existsSync()) {
          dest.deleteSync(recursive: true);
        }
        globals.fsUtils.copyDirectorySync(source, dest);
        created.add(dest);
      }
      return await runInternal();
    } finally {
      for (final Directory template in created) {
        template.deleteSync(recursive: true);
      }
    }
  }
}
