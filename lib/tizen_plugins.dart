// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_system/targets/web.dart';
import 'package:flutter_tools/src/dart/language_version.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/dart/package_map.dart';
import 'package:flutter_tools/src/platform_plugins.dart';
import 'package:flutter_tools/src/plugins.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:meta/meta.dart';
import 'package:package_config/package_config.dart';
import 'package:yaml/yaml.dart';

import 'tizen_project.dart';

/// Contains the parameters to template a Tizen plugin.
///
/// The [name] of the plugin is required. Either [dartPluginClass] or
/// [pluginClass] are required. [pluginClass] will be the entry point to the
/// plugin's native code. If [pluginClass] is not empty, the [fileName]
/// containing the plugin's code is required.
///
/// Source: [LinuxPlugin] in `platform_plugins.dart`
class TizenPlugin extends PluginPlatform implements NativeOrDartPlugin {
  TizenPlugin({
    @required this.name,
    @required this.directory,
    this.pluginClass,
    this.dartPluginClass,
    this.fileName,
  }) : assert(pluginClass != null || dartPluginClass != null);

  factory TizenPlugin.fromYaml(String name, Directory directory, YamlMap yaml) {
    assert(validate(yaml));
    return TizenPlugin(
      name: name,
      directory: directory,
      pluginClass: yaml[kPluginClass] as String,
      dartPluginClass: yaml[kDartPluginClass] as String,
      fileName: yaml['fileName'] as String,
    );
  }

  static bool validate(YamlMap yaml) {
    if (yaml == null) {
      return false;
    }
    return yaml[kPluginClass] is String || yaml[kDartPluginClass] is String;
  }

  static const String kConfigKey = 'tizen';

  final String name;
  final Directory directory;
  final String pluginClass;
  final String dartPluginClass;
  final String fileName;

  @override
  bool isNative() => pluginClass != null;

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      if (pluginClass != null) 'class': pluginClass,
      if (dartPluginClass != null) 'dartPluginClass': dartPluginClass,
      'file': fileName,
    };
  }

  File get projectFile => directory.childFile('project_def.prop');

  final RegExp _propertyFormat = RegExp(r'(\S+)\s*\+?=(.*)');

  Map<String, String> _properties;

  String getProperty(String key) {
    if (_properties == null) {
      if (!projectFile.existsSync()) {
        return null;
      }
      _properties = <String, String>{};

      for (final String line in projectFile.readAsLinesSync()) {
        final Match match = _propertyFormat.firstMatch(line);
        if (match == null) {
          continue;
        }
        final String key = match.group(1);
        final String value = match.group(2).trim();
        _properties[key] = value;
      }
    }
    return _properties.containsKey(key) ? _properties[key] : null;
  }

  List<String> getPropertyAsAbsolutePaths(String key) {
    final String property = getProperty(key);
    if (property == null) {
      return <String>[];
    }

    final List<String> paths = <String>[];
    for (final String element in property.split(' ')) {
      if (globals.fs.path.isAbsolute(element)) {
        paths.add(element);
      } else {
        paths.add(globals.fs.path
            .normalize(globals.fs.path.join(directory.path, element)));
      }
    }
    return paths;
  }
}

/// Any [FlutterCommand] that invokes [usesPubOption] or [targetFile] should
/// depend on this mixin to ensure plugins are correctly configured for Tizen.
///
/// See: [FlutterCommand.verifyThenRunCommand] in `flutter_command.dart`
mixin TizenExtension on FlutterCommand {
  String _entrypoint;

  bool get _usesTargetOption => argParser.options.containsKey('target');

  @override
  Future<FlutterCommandResult> verifyThenRunCommand(String commandPath) async {
    if (super.shouldRunPub) {
      // TODO(swift-kim): Should run pub get first before injecting plugins.
      await ensureReadyForTizenTooling(FlutterProject.current());
    }
    if (_usesTargetOption) {
      _entrypoint =
          await _createEntrypoint(FlutterProject.current(), super.targetFile);
    }
    return await super.verifyThenRunCommand(commandPath);
  }

  @override
  String get targetFile => _entrypoint ?? super.targetFile;
}

/// Creates an entrypoint wrapper of [targetFile] and returns its path.
/// This effectively adds support for Dart plugins.
///
/// Source: [WebEntrypointTarget.build] in `web.dart`
Future<String> _createEntrypoint(
    FlutterProject project, String targetFile) async {
  final List<TizenPlugin> dartPlugins =
      await findTizenPlugins(project, dartOnly: true);
  if (dartPlugins.isEmpty) {
    return targetFile;
  }

  final TizenProject tizenProject = TizenProject.fromFlutter(project);
  if (!tizenProject.existsSync()) {
    return targetFile;
  }

  final File entrypoint = tizenProject.managedDirectory.childFile('main.dart')
    ..createSync(recursive: true);
  final PackageConfig packageConfig = await loadPackageConfigWithLogging(
    project.directory.childFile('.packages'),
    logger: globals.logger,
  );
  final FlutterProject flutterProject = FlutterProject.current();
  final LanguageVersion languageVersion = determineLanguageVersion(
    globals.fs.file(targetFile),
    packageConfig[flutterProject.manifest.appName],
  );

  final Uri mainUri = globals.fs.file(targetFile).absolute.uri;
  final String mainImport =
      packageConfig.toPackageUri(mainUri)?.toString() ?? mainUri.toString();

  entrypoint.writeAsStringSync('''
//
// Generated file. Do not edit.
//
// @dart=${languageVersion.major}.${languageVersion.minor}

import '$mainImport' as entrypoint;
import 'generated_plugin_registrant.dart';

Future<void> main() async {
  registerPlugins();
  entrypoint.main();
}
''');
  return entrypoint.path;
}

const List<String> _knownPlugins = <String>[
  'audioplayers',
  'battery',
  'connectivity',
  'device_info',
  'flutter_tts',
  'image_picker',
  'integration_test',
  'package_info',
  'path_provider',
  'permission_handler',
  'sensors',
  'share',
  'shared_preferences',
  'url_launcher',
  'video_player',
  'webview_flutter',
  'wifi_info_flutter',
];

/// This function must be called whenever [FlutterProject.regeneratePlatformSpecificTooling]
/// or [FlutterProject.ensureReadyForPlatformSpecificTooling] is called.
///
/// See: [FlutterProject.ensureReadyForPlatformSpecificTooling] in `project.dart`
Future<void> ensureReadyForTizenTooling(FlutterProject project) async {
  if (!project.directory.existsSync() || project.hasExampleApp) {
    return;
  }
  final TizenProject tizenProject = TizenProject.fromFlutter(project);
  await tizenProject.ensureReadyForPlatformSpecificTooling();

  await injectTizenPlugins(project);
}

/// See: [injectPlugins] in `plugins.dart`
Future<void> injectTizenPlugins(FlutterProject project) async {
  final TizenProject tizenProject = TizenProject.fromFlutter(project);
  if (tizenProject.existsSync()) {
    final List<TizenPlugin> dartPlugins =
        await findTizenPlugins(project, dartOnly: true);
    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, nativeOnly: true);
    _writeDartPluginRegistrant(tizenProject.managedDirectory, dartPlugins);
    _writeCppPluginRegistrant(tizenProject.managedDirectory, nativePlugins);
    _writeCsharpPluginRegistrant(tizenProject.managedDirectory, nativePlugins);
  }

  final List<String> plugins =
      (await findPlugins(project)).map((Plugin p) => p.name).toList();
  for (final String plugin in plugins) {
    final String tizenPlugin = '${plugin}_tizen';
    if (_knownPlugins.contains(plugin) && !plugins.contains(tizenPlugin)) {
      globals.printStatus(
        '$tizenPlugin is available on pub.dev. Did you forget to add to pubspec.yaml?',
        color: TerminalColor.yellow,
      );
    }
  }
}

/// Source: [findPlugins] in `plugins.dart`
Future<List<TizenPlugin>> findTizenPlugins(
  FlutterProject project, {
  bool dartOnly = false,
  bool nativeOnly = false,
}) async {
  final List<TizenPlugin> plugins = <TizenPlugin>[];
  final File packagesFile = project.directory.childFile('.packages');
  final PackageConfig packageConfig = await loadPackageConfigWithLogging(
    packagesFile,
    logger: globals.logger,
  );
  for (final Package package in packageConfig.packages) {
    final Uri packageRoot = package.packageUriRoot.resolve('..');
    final TizenPlugin plugin = _pluginFromPackage(package.name, packageRoot);
    if (plugin == null) {
      continue;
    } else if (nativeOnly && plugin.pluginClass == null) {
      continue;
    } else if (dartOnly && plugin.dartPluginClass == null) {
      continue;
    }
    plugins.add(plugin);
  }
  return plugins;
}

/// Source: [_pluginFromPackage] in `plugins.dart`
TizenPlugin _pluginFromPackage(String name, Uri packageRoot) {
  final String pubspecPath =
      globals.fs.path.fromUri(packageRoot.resolve('pubspec.yaml'));
  if (!globals.fs.isFileSync(pubspecPath)) {
    return null;
  }

  dynamic pubspec;
  try {
    pubspec = loadYaml(globals.fs.file(pubspecPath).readAsStringSync());
  } on YamlException catch (err) {
    globals.printTrace('Failed to parse plugin manifest for $name: $err');
  }
  if (pubspec == null) {
    return null;
  }
  final dynamic flutterConfig = pubspec['flutter'];
  if (flutterConfig == null || !(flutterConfig.containsKey('plugin') as bool)) {
    return null;
  }

  final Directory packageDir = globals.fs.directory(packageRoot);
  globals.printTrace('Found plugin $name at ${packageDir.path}');

  final YamlMap pluginYaml = flutterConfig['plugin'] as YamlMap;
  if (pluginYaml == null || pluginYaml['platforms'] == null) {
    return null;
  }
  final YamlMap platformsYaml = pluginYaml['platforms'] as YamlMap;
  if (platformsYaml == null || platformsYaml[TizenPlugin.kConfigKey] == null) {
    return null;
  }
  return TizenPlugin.fromYaml(
    name,
    packageDir.childDirectory('tizen'),
    platformsYaml[TizenPlugin.kConfigKey] as YamlMap,
  );
}

/// See: [_writeWebPluginRegistrant] in `plugins.dart`
void _writeDartPluginRegistrant(
  Directory registryDirectory,
  List<TizenPlugin> plugins,
) {
  final List<Map<String, dynamic>> pluginConfigs =
      plugins.map((TizenPlugin plugin) => plugin.toMap()).toList();
  final Map<String, dynamic> context = <String, dynamic>{
    'plugins': pluginConfigs,
  };
  _renderTemplateToFile(
    '''
//
// Generated file. Do not edit.
//
// ignore_for_file: lines_longer_than_80_chars

{{#plugins}}
import 'package:{{name}}/{{name}}.dart';
{{/plugins}}

// ignore: public_member_api_docs
void registerPlugins() {
{{#plugins}}
  {{dartPluginClass}}.register();
{{/plugins}}
}
''',
    context,
    registryDirectory.childFile('generated_plugin_registrant.dart').path,
  );
}

/// See: [_writeWindowsPluginFiles] in `plugins.dart`
void _writeCppPluginRegistrant(
  Directory registryDirectory,
  List<TizenPlugin> plugins,
) {
  final List<Map<String, dynamic>> pluginConfigs =
      plugins.map((TizenPlugin plugin) => plugin.toMap()).toList();
  final Map<String, dynamic> context = <String, dynamic>{
    'plugins': pluginConfigs,
  };
  _renderTemplateToFile(
    '''
//
// Generated file. Do not edit.
//
#ifndef GENERATED_PLUGIN_REGISTRANT_
#define GENERATED_PLUGIN_REGISTRANT_

#include <flutter/plugin_registry.h>

{{#plugins}}
#include "{{file}}"
{{/plugins}}

// Registers Flutter plugins.
void RegisterPlugins(flutter::PluginRegistry *registry) {
{{#plugins}}
  {{class}}RegisterWithRegistrar(
      registry->GetRegistrarForPlugin("{{class}}"));
{{/plugins}}
}

#endif  // GENERATED_PLUGIN_REGISTRANT_
''',
    context,
    registryDirectory.childFile('generated_plugin_registrant.h').path,
  );
}

void _writeCsharpPluginRegistrant(
  Directory registryDirectory,
  List<TizenPlugin> plugins,
) {
  final List<Map<String, dynamic>> pluginConfigs =
      plugins.map((TizenPlugin plugin) => plugin.toMap()).toList();
  final Map<String, dynamic> context = <String, dynamic>{
    'plugins': pluginConfigs,
  };
  _renderTemplateToFile(
    '''
//
// Generated file. Do not edit.
//
using System;
using System.Runtime.InteropServices;
using Tizen.Flutter.Embedding;

namespace Runner
{
    internal class GeneratedPluginRegistrant
    {
      {{#plugins}}
        [DllImport("flutter_plugins.so")]
        public static extern void {{class}}RegisterWithRegistrar(
            FlutterDesktopPluginRegistrar registrar);
      {{/plugins}}

        public static void RegisterPlugins(IPluginRegistry registry)
        {
          {{#plugins}}
            {{class}}RegisterWithRegistrar(
                registry.GetRegistrarForPlugin("{{class}}"));
          {{/plugins}}
        }
    }
}
''',
    context,
    registryDirectory.childFile('GeneratedPluginRegistrant.cs').path,
  );
}

/// Source: [_renderTemplateToFile] in `plugins.dart` (direct copy)
void _renderTemplateToFile(String template, dynamic context, String filePath) {
  final String renderedTemplate = globals.templateRenderer
      .renderString(template, context, htmlEscapeValues: false);
  final File file = globals.fs.file(filePath);
  file.createSync(recursive: true);
  file.writeAsStringSync(renderedTemplate);
}
