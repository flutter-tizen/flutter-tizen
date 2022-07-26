// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/base/utils.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/create.dart';
import 'package:flutter_tools/src/flutter_project_metadata.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/template.dart';

import '../tizen_project.dart';

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
      allowed: <String>['cpp', 'csharp'],
      help: 'The language to use for Tizen-specific code, either C++ '
          '(performant, but unsupported by TV devices) or C# (universal). '
          'If not specfied, "cpp" is used by default if the project type is '
          '"plugin", otherwise "csharp" is used by default.',
    );
    argParser.addOption(
      'app-type',
      allowed: <String>['ui', 'service', 'multi'],
      allowedHelp: <String, String>{
        'ui':
            '(default) Generate an application with a graphical user interface '
                'that runs in the foreground.',
        'service':
            'Generate a service application that runs in the background.',
        'multi':
            'Generate a multi-project application that consists of both UI and service parts.',
      },
      help: 'Select a type of application template.',
    );
  }

  String get appType => stringArg('app-type') ?? 'ui';

  String get tizenLanguage {
    if (argResults.wasParsed('tizen-language')) {
      return stringArg('tizen-language');
    }
    return stringArg('template') == 'plugin' ? 'cpp' : 'csharp';
  }

  Directory get _tizenTemplates => globals.fs
      .directory(Cache.flutterRoot)
      .parent
      .childDirectory('templates');

  Directory get _flutterTemplates => globals.fs
      .directory(Cache.flutterRoot)
      .childDirectory('packages')
      .childDirectory('flutter_tools')
      .childDirectory('templates');

  /// See: [CreateCommand._getProjectType] in `create.dart`
  bool get _shouldGeneratePlugin {
    FlutterProjectType template;
    if (argResults['template'] != null) {
      template = stringToProjectType(stringArg('template'));
    }
    if (projectDir.existsSync() && projectDir.listSync().isNotEmpty) {
      template = determineTemplateType();
    }
    return template == FlutterProjectType.plugin;
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
    bool printStatusWhenWriting = true,
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
    return template.render(
      directory,
      context,
      overwriteExisting: overwrite,
      printStatusWhenWriting: printStatusWhenWriting,
    );
  }

  @override
  Future<int> renderMerged(
    List<String> names,
    Directory directory,
    Map<String, Object> context, {
    bool overwrite = false,
    bool printStatusWhenWriting = true,
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
    return template.render(
      directory,
      context,
      overwriteExisting: overwrite,
      printStatusWhenWriting: printStatusWhenWriting,
    );
  }

  /// See: [CreateCommand._generateMethodChannelPlugin] in `create.dart`
  @override
  Future<int> generateApp(
    List<String> templateNames,
    Directory directory,
    Map<String, Object> templateContext, {
    bool overwrite = false,
    bool pluginExampleApp = false,
    bool printStatusWhenWriting = true,
    bool generateMetadata = true,
    FlutterProjectType projectType,
  }) async {
    if (pluginExampleApp) {
      // Reset to the updated identifier for the example app.
      templateContext['tizenIdentifier'] = templateContext['androidIdentifier'];
      // Example app is always generated in C#.
      templateContext['tizenLanguage'] = 'csharp';
    }

    return super.generateApp(
      templateNames,
      directory,
      templateContext,
      overwrite: overwrite,
      pluginExampleApp: pluginExampleApp,
      printStatusWhenWriting: printStatusWhenWriting,
      generateMetadata: generateMetadata,
      projectType: projectType,
    );
  }

  @override
  Map<String, Object> createTemplateContext({
    String organization,
    String projectName,
    String titleCaseProjectName,
    String projectDescription,
    String androidLanguage,
    String iosDevelopmentTeam,
    String iosLanguage,
    String flutterRoot,
    String dartSdkVersionBounds,
    String agpVersion,
    String kotlinVersion,
    String gradleVersion,
    bool withPlatformChannelPluginHook = false,
    bool withFfiPluginHook = false,
    bool ios = false,
    bool android = false,
    bool web = false,
    bool linux = false,
    bool macos = false,
    bool windows = false,
    bool windowsUwp = false,
    bool implementationTests = false,
  }) {
    final Map<String, Object> context = super.createTemplateContext(
      organization: organization,
      projectName: projectName,
      titleCaseProjectName: titleCaseProjectName,
      projectDescription: projectDescription,
      androidLanguage: androidLanguage,
      iosDevelopmentTeam: iosDevelopmentTeam,
      iosLanguage: iosLanguage,
      flutterRoot: flutterRoot,
      dartSdkVersionBounds: dartSdkVersionBounds,
      agpVersion: agpVersion,
      kotlinVersion: kotlinVersion,
      gradleVersion: gradleVersion,
      withPlatformChannelPluginHook: withPlatformChannelPluginHook,
      withFfiPluginHook: withFfiPluginHook,
      ios: ios,
      android: android,
      web: web,
      linux: linux,
      macos: macos,
      windows: windows,
      windowsUwp: windowsUwp,
      implementationTests: implementationTests,
    );
    context['tizen'] = true;
    context['tizenIdentifier'] = context['androidIdentifier'];
    context['tizenLanguage'] = tizenLanguage;
    context['tizenNamespace'] = _createNamespaceName(projectName);
    return context;
  }

  @override
  Future<void> validateCommand() async {
    await super.validateCommand();

    final String template = stringArg('template') ?? 'app';

    if (template != 'app' && argResults.wasParsed('app-type')) {
      throwToolExit(
          '--app-type=$appType and --template=$template cannot be provided at the same time.');
    }

    if (template == 'plugin_ffi') {
      throwToolExit('Creating an FFI plugin project is not yet supported.');
    }

    final String templateName = template == 'app' ? '$appType-app' : template;
    if (!_tizenTemplates
        .childDirectory(templateName)
        .childDirectory(tizenLanguage)
        .existsSync()) {
      throwToolExit(
          'Could not locate a template: $templateName/$tizenLanguage');
    }
  }

  /// See: [CreateCommand.runCommand] in `create.dart`
  Future<FlutterCommandResult> _runCommand() async {
    final FlutterCommandResult result = await super.runCommand();
    if (result != FlutterCommandResult.success()) {
      return result;
    }

    if (_shouldGeneratePlugin) {
      // Generate .csproj.user file if the plugin is a dotnet project.
      final FlutterProject project = FlutterProject.fromDirectory(projectDir);
      final TizenProject tizenProject = TizenProject.fromFlutter(project);
      if (tizenProject.existsSync() && tizenProject.isDotnet) {
        updateDotnetUserProjectFile(tizenProject.projectFile);
      }

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
      if (templateContext['tizenLanguage'] == 'csharp') {
        globals.printStatus(
          '\nflutter:\n'
          '  plugin:\n'
          '    platforms:\n'
          '      tizen:\n'
          '        namespace: ${templateContext['tizenNamespace'] as String}\n'
          '        pluginClass: ${templateContext['pluginClass'] as String}\n'
          '        fileName: ${templateContext['pluginClass'] as String}.csproj',
          color: TerminalColor.blue,
        );
      } else if (templateContext['tizenLanguage'] == 'cpp') {
        globals.printStatus(
          '\nflutter:\n'
          '  plugin:\n'
          '    platforms:\n'
          '      tizen:\n'
          '        pluginClass: ${templateContext['pluginClass'] as String}\n'
          '        fileName: ${projectName}_plugin.h',
          color: TerminalColor.blue,
        );
      }
      globals.printStatus('');
    }

    return result;
  }

  /// See:
  /// - [CreateCommand._generateMethodChannelPlugin] in `create.dart`
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

    _runGitClean(_flutterTemplates);
    try {
      // The template directory that the flutter tools search for available
      // templates cannot be overriden because the implementation is private.
      // So we have to copy Tizen templates into the directory manually.
      await _copyTizenTemplatesToFlutter();

      return await _runCommand();
    } finally {
      _runGitClean(_flutterTemplates);
    }
  }

  Future<void> _copyTizenTemplatesToFlutter() async {
    // Copy application template to the flutter_tools/templates directory.
    // Even if the requested template type is plugin, an app template is
    // required for generating the example app.
    final Directory appTemplate =
        _tizenTemplates.childDirectory('$appType-app');
    _copyDirectoryIfExists(
      appTemplate.childDirectory('cpp'),
      _flutterTemplates
          .childDirectory('app_shared')
          .childDirectory('tizen-cpp.tmpl'),
    );
    _copyDirectoryIfExists(
      appTemplate.childDirectory('csharp'),
      _flutterTemplates
          .childDirectory('app_shared')
          .childDirectory('tizen-csharp.tmpl'),
    );
    _copyDirectoryIfExists(
      appTemplate.childDirectory('lib'),
      _flutterTemplates.childDirectory('app').childDirectory('lib'),
    );

    // Copy plugin template to the flutter_tools/templates directory.
    final Directory pluginTemplate = _tizenTemplates.childDirectory('plugin');
    _copyDirectoryIfExists(
      pluginTemplate.childDirectory('cpp'),
      _flutterTemplates
          .childDirectory('plugin')
          .childDirectory('tizen-cpp.tmpl'),
    );
    _copyDirectoryIfExists(
      pluginTemplate.childDirectory('csharp'),
      _flutterTemplates
          .childDirectory('plugin')
          .childDirectory('tizen-csharp.tmpl'),
    );

    // Apply patches if found.
    for (final Directory template in <Directory>[
      appTemplate,
      pluginTemplate,
      _tizenTemplates.childDirectory('module'),
    ]) {
      for (final File file in template.listSync().whereType<File>()) {
        if (file.basename.endsWith('.patch')) {
          _runGitApply(_flutterTemplates, file);
        }
      }
    }
  }

  void _copyDirectoryIfExists(Directory source, Directory target) {
    if (source.existsSync()) {
      copyDirectory(source, target);
    }
  }

  void _runGitClean(Directory directory) {
    ProcessResult result = globals.processManager.runSync(
      <String>['git', 'checkout', '--', '.'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to run git checkout: ${result.stderr}');
    }
    result = globals.processManager.runSync(
      <String>['git', 'clean', '-df', '.'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to run git clean: ${result.stderr}');
    }
  }

  void _runGitApply(Directory directory, File patchFile) {
    final ProcessResult result = globals.processManager.runSync(
      <String>['git', 'apply', patchFile.path],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to run git apply: ${result.stderr}');
    }
  }
}

String _createNamespaceName(String name) {
  final String camelizedName = camelCase(name);
  return camelizedName[0].toUpperCase() + camelizedName.substring(1);
}
