// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:cli';

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_system/targets/web.dart';
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
/// [pluginClass] are required. The [fileName] containing the plugin's code is
/// required. [pluginClass] will be the entry point to the plugin's native code.
///
/// Source: [LinuxPlugin] in `platform_plugins.dart`
class TizenPlugin extends PluginPlatform implements NativeOrDartPlugin {
  const TizenPlugin({
    @required this.name,
    @required this.path,
    this.pluginClass,
    this.dartPluginClass,
    @required this.fileName,
  }) : assert(pluginClass != null || dartPluginClass != null);

  factory TizenPlugin.fromYaml(String name, String path, YamlMap yaml) {
    assert(validate(yaml));
    return TizenPlugin(
      name: name,
      path: path,
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
  final String path;
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
      if (pluginClass != null)
        'sofile': fileName.toLowerCase().replaceFirst('.h', '.so'),
    };
  }
}

/// Any [FlutterCommand] that uses [usesPubOption] or invokes [targetFile]
/// should depend on this mixin to ensure plugins are correctly configured for
/// Tizen.
///
/// See: [FlutterCommand.verifyThenRunCommand] in `flutter_command.dart`
mixin TizenExtension on FlutterCommand {
  String entrypoint;

  @override
  String get targetFile {
    // Caution: Converting async to sync.
    return entrypoint ??= waitFor<String>(
        _createEntrypoint(FlutterProject.current(), super.targetFile));
  }

  @override
  Future<FlutterCommandResult> verifyThenRunCommand(String commandPath) async {
    if (super.shouldRunPub) {
      final FlutterProject project = FlutterProject.current();
      await injectTizenPlugins(project);
    }
    return await super.verifyThenRunCommand(commandPath);
  }
}

/// Creates an entrypoint wrapper of [targetFile] and returns its path.
/// Required to support Dart plugins.
/// Doesn't currently work with the route option.
///
/// Source: [WebEntrypointTarget.build] in `web.dart`
Future<String> _createEntrypoint(
    FlutterProject project, String targetFile) async {
  final bool hasDartPlugins =
      (await findTizenPlugins(project, filterDart: true)).isNotEmpty;
  if (!hasDartPlugins) {
    return targetFile;
  }

  final TizenProject tizenProject = TizenProject.fromFlutter(project);
  final Directory registryDirectory = tizenProject.managedDirectory;
  final File entrypoint = registryDirectory.childFile('main.dart');
  final PackageConfig packageConfig = await loadPackageConfigWithLogging(
    project.directory.childFile('.packages'),
    logger: globals.logger,
  );
  final Uri mainUri = globals.fs.file(targetFile).absolute.uri;
  final String mainImport =
      packageConfig.toPackageUri(mainUri)?.toString() ?? mainUri.toString();

  entrypoint.writeAsStringSync('''
//
// Generated file. Do not edit.
//
import '$mainImport' as entrypoint;
import 'generated_plugin_registrant.dart';

Future<void> main() async {
  registerPlugins();
  entrypoint.main();
}
''');
  return entrypoint.path;
}

/// This method has the same role as [ensureReadyForPlatformSpecificTooling].
///
/// See:
/// - [FlutterProject.ensureReadyForPlatformSpecificTooling] in `project.dart`
/// - [injectPlugins] in `plugins.dart`
Future<void> injectTizenPlugins(FlutterProject project) async {
  if (!project.directory.existsSync() || project.hasExampleApp) {
    return;
  }

  final TizenProject tizenProject = TizenProject.fromFlutter(project);
  if (tizenProject.existsSync()) {
    final List<TizenPlugin> dartPlugins =
        await findTizenPlugins(project, filterDart: true);
    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, filterNative: true);
    await _writeDartPluginRegistrant(
        tizenProject.managedDirectory, dartPlugins);
    await _writeCppPluginRegistrant(
        tizenProject.managedDirectory, nativePlugins);
    await _writeCsharpPluginRegistrant(
        tizenProject.managedDirectory, nativePlugins);
  }
}

/// Source: [findPlugins] in `plugins.dart`
Future<List<TizenPlugin>> findTizenPlugins(
  FlutterProject project, {
  bool filterDart = false,
  bool filterNative = false,
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
    } else if (filterNative && plugin.pluginClass == null) {
      continue;
    } else if (filterDart && plugin.pluginClass != null) {
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
    packageDir.childDirectory('tizen').path,
    platformsYaml[TizenPlugin.kConfigKey] as YamlMap,
  );
}

/// See: [_writeWebPluginRegistrant] in `plugins.dart`
Future<void> _writeDartPluginRegistrant(
    Directory registryDirectory, List<TizenPlugin> plugins) async {
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
{{#plugins}}
import 'package:{{name}}/{{file}}';
{{/plugins}}

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
Future<void> _writeCppPluginRegistrant(
    Directory registryDirectory, List<TizenPlugin> plugins) async {
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

#include "flutter_tizen.h"

{{#plugins}}
#include "{{file}}"
{{/plugins}}

// Registers Flutter plugins.
void RegisterPlugins(FlutterWindowControllerRef window) {
{{#plugins}}
  {{class}}RegisterWithRegistrar(
      FlutterDesktopGetPluginRegistrar(window, "{{class}}"));
{{/plugins}}
}

#endif  // GENERATED_PLUGIN_REGISTRANT_
''',
    context,
    registryDirectory.childFile('generated_plugin_registrant.h').path,
  );
}

Future<void> _writeCsharpPluginRegistrant(
    Directory registryDirectory, List<TizenPlugin> plugins) async {
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
        [DllImport("{{sofile}}")]
        public static extern void {{class}}RegisterWithRegistrar(IntPtr registrar);
      {{/plugins}}

        public static void RegisterPlugins(FlutterApplication app)
        {
          {{#plugins}}
            {{class}}RegisterWithRegistrar(app.GetPluginRegistrar("{{class}}"));
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
