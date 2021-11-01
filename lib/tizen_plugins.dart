// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/terminal.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:flutter_tools/src/build_system/targets/web.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/dart/language_version.dart';
import 'package:flutter_tools/src/dart/package_map.dart';
import 'package:flutter_tools/src/flutter_plugins.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/platform_plugins.dart';
import 'package:flutter_tools/src/plugins.dart';
import 'package:flutter_tools/src/project.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:flutter_tools/src/runner/flutter_command.dart';
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
    required this.name,
    required this.directory,
    this.pluginClass,
    this.dartPluginClass,
    this.fileName,
  }) : assert(pluginClass != null || dartPluginClass != null);

  static TizenPlugin fromYaml(String name, Directory directory, YamlMap yaml) {
    assert(validate(yaml));
    return TizenPlugin(
      name: name,
      directory: directory,
      pluginClass: yaml[kPluginClass] as String?,
      dartPluginClass: yaml[kDartPluginClass] as String?,
      fileName: yaml['fileName'] as String?,
    );
  }

  static bool validate(YamlMap yaml) {
    return yaml[kPluginClass] is String || yaml[kDartPluginClass] is String;
  }

  static const String kConfigKey = 'tizen';

  final String name;
  final Directory directory;
  final String? pluginClass;
  final String? dartPluginClass;
  final String? fileName;

  TizenPlugin copyWith({Directory? directory}) {
    return TizenPlugin(
      name: name,
      directory: directory ?? this.directory,
      pluginClass: pluginClass,
      dartPluginClass: dartPluginClass,
      fileName: fileName,
    );
  }

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
}

/// Any [FlutterCommand] that references [targetFile] should extend this mixin
/// to ensure that `generated_main.dart` is created and updated properly.
///
/// See: [FlutterCommand.verifyThenRunCommand] in `flutter_command.dart`
mixin DartPluginRegistry on FlutterCommand {
  String? _targetFile;

  bool get _usesTargetOption => argParser.options.containsKey('target');

  @override
  Future<FlutterCommandResult> verifyThenRunCommand(String commandPath) async {
    final FlutterProject project = FlutterProject.current();
    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    if (_usesTargetOption && tizenProject.existsSync()) {
      final File mainDart = globals.fs.file(super.targetFile);
      final File generatedMainDart =
          tizenProject.managedDirectory.childFile('generated_main.dart');
      await _generateEntrypointWithPluginRegistrant(
          project, mainDart, generatedMainDart);
      _targetFile = generatedMainDart.path;
    }
    return super.verifyThenRunCommand(commandPath);
  }

  @override
  String get targetFile => _targetFile ?? super.targetFile;
}

/// See:
/// - [WebEntrypointTarget.build] in `web.dart`
/// - [generateMainDartWithPluginRegistrant] in `flutter_plugins.dart`
Future<void> _generateEntrypointWithPluginRegistrant(
  FlutterProject project,
  File mainFile,
  File newMainFile,
) async {
  final PackageConfig packageConfig = await loadPackageConfigWithLogging(
    project.packageConfigFile,
    logger: globals.logger,
  );
  final Uri mainFileUri = mainFile.absolute.uri;
  final LanguageVersion languageVersion = determineLanguageVersion(
    mainFile,
    packageConfig.packageOf(mainFileUri),
    Cache.flutterRoot!,
  );
  final Uri mainUri = packageConfig.toPackageUri(mainFileUri) ?? mainFileUri;
  final List<TizenPlugin> dartPlugins =
      await findTizenPlugins(project, dartOnly: true);

  final Map<String, Object> context = <String, Object>{
    'mainImport': mainUri.toString(),
    'dartLanguageVersion': languageVersion.toString(),
    'plugins': dartPlugins.map((TizenPlugin plugin) => plugin.toMap()),
  };
  renderTemplateToFile(
    '''
//
// Generated file. Do not edit.
//
// @dart = {{dartLanguageVersion}}

// ignore_for_file: avoid_classes_with_only_static_members
// ignore_for_file: avoid_private_typedef_functions
// ignore_for_file: directives_ordering
// ignore_for_file: lines_longer_than_80_chars
// ignore_for_file: unnecessary_cast

import '{{mainImport}}' as entrypoint;
{{#plugins}}
import 'package:{{name}}/{{name}}.dart';
{{/plugins}}

export '{{mainImport}}';

@pragma('vm:entry-point')
class _PluginRegistrant {
  @pragma('vm:entry-point')
  static void register() {
{{#plugins}}
    {{dartPluginClass}}.register();
{{/plugins}}
  }
}

typedef _UnaryFunction = dynamic Function(List<String> args);
typedef _NullaryFunction = dynamic Function();

@pragma('vm:entry-point')
void main(List<String> args) {
  if (entrypoint.main is _UnaryFunction) {
    (entrypoint.main as _UnaryFunction)(args);
  } else {
    (entrypoint.main as _NullaryFunction)();
  }
}
''',
    context,
    newMainFile,
  );
}

/// https://github.com/flutter-tizen/plugins
const List<String> _kKnownPlugins = <String>[
  'audioplayers',
  'battery',
  'battery_plus',
  'camera',
  'connectivity',
  'connectivity_plus',
  'device_info',
  'device_info_plus',
  'flutter_tts',
  'geolocator',
  'google_maps_flutter',
  'image_picker',
  'integration_test',
  'network_info_plus',
  'package_info',
  'package_info_plus',
  'path_provider',
  'permission_handler',
  'sensors',
  'sensors_plus',
  'share',
  'share_plus',
  'shared_preferences',
  'url_launcher',
  'video_player',
  'wakelock',
  'webview_flutter',
  'wifi_info_flutter',
];

/// This function is expected to be called whenever
/// [FlutterProject.ensureReadyForPlatformSpecificTooling] is called.
///
/// See: [FlutterProject.ensureReadyForPlatformSpecificTooling] in `project.dart`
Future<void> ensureReadyForTizenTooling(FlutterProject project) async {
  if (!project.directory.existsSync() ||
      project.hasExampleApp ||
      project.isPlugin) {
    return;
  }
  final TizenProject tizenProject = TizenProject.fromFlutter(project);
  if (!tizenProject.existsSync()) {
    return;
  }
  await tizenProject.ensureReadyForPlatformSpecificTooling();

  await injectTizenPlugins(project);
}

/// See: [injectPlugins] in `flutter_plugins.dart`
Future<void> injectTizenPlugins(FlutterProject project) async {
  final TizenProject tizenProject = TizenProject.fromFlutter(project);
  if (tizenProject.existsSync()) {
    final List<TizenPlugin> nativePlugins =
        await findTizenPlugins(project, nativeOnly: true);
    _writeCppPluginRegistrant(tizenProject.managedDirectory, nativePlugins);
    _writeCsharpPluginRegistrant(tizenProject.managedDirectory, nativePlugins);
  }

  final List<String> plugins =
      (await findPlugins(project)).map((Plugin p) => p.name).toList();
  for (final String plugin in plugins) {
    final String tizenPlugin = '${plugin}_tizen';
    if (_kKnownPlugins.contains(plugin) && !plugins.contains(tizenPlugin)) {
      globals.printStatus(
        '$tizenPlugin is available on pub.dev. Did you forget to add to pubspec.yaml?',
        color: TerminalColor.yellow,
      );
    }
  }
}

/// Source: [findPlugins] in `flutter_plugins.dart`
Future<List<TizenPlugin>> findTizenPlugins(
  FlutterProject project, {
  bool dartOnly = false,
  bool nativeOnly = false,
  bool throwOnError = true,
}) async {
  final List<TizenPlugin> plugins = <TizenPlugin>[];
  final FileSystem fs = project.directory.fileSystem;
  final PackageConfig packageConfig = await loadPackageConfigWithLogging(
    project.packageConfigFile,
    logger: globals.logger,
    throwOnError: throwOnError,
  );
  for (final Package package in packageConfig.packages) {
    final Uri packageRoot = package.packageUriRoot.resolve('..');
    final TizenPlugin? plugin = _pluginFromPackage(
      package.name,
      packageRoot,
      fileSystem: fs,
    );
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

/// Source: [_pluginFromPackage] in `flutter_plugins.dart`
TizenPlugin? _pluginFromPackage(
  String name,
  Uri packageRoot, {
  FileSystem? fileSystem,
}) {
  final FileSystem fs = fileSystem ?? globals.fs;
  final String pubspecPath =
      fs.path.fromUri(packageRoot.resolve('pubspec.yaml'));
  if (!fs.isFileSync(pubspecPath)) {
    return null;
  }

  Object? pubspec;
  try {
    pubspec = loadYaml(fs.file(pubspecPath).readAsStringSync());
  } on YamlException catch (err) {
    globals.printTrace('Failed to parse plugin manifest for $name: $err');
  }
  if (pubspec == null || pubspec is! YamlMap) {
    return null;
  }
  final Object? flutterConfig = pubspec['flutter'];
  if (flutterConfig == null ||
      flutterConfig is! YamlMap ||
      !flutterConfig.containsKey('plugin')) {
    return null;
  }

  final Directory packageDir = fs.directory(packageRoot);
  globals.printTrace('Found plugin $name at ${packageDir.path}');

  final YamlMap? pluginYaml = flutterConfig['plugin'] as YamlMap?;
  if (pluginYaml == null || pluginYaml['platforms'] == null) {
    return null;
  }
  final YamlMap? platformsYaml = pluginYaml['platforms'] as YamlMap?;
  if (platformsYaml == null || platformsYaml[TizenPlugin.kConfigKey] == null) {
    return null;
  }
  return TizenPlugin.fromYaml(
    name,
    packageDir.childDirectory('tizen'),
    platformsYaml[TizenPlugin.kConfigKey]! as YamlMap,
  );
}

/// See: [writeWindowsPluginFiles] in `flutter_plugins.dart`
void _writeCppPluginRegistrant(
  Directory registryDirectory,
  List<TizenPlugin> plugins,
) {
  final List<Map<String, Object?>> pluginConfigs =
      plugins.map((TizenPlugin plugin) => plugin.toMap()).toList();
  final Map<String, Object> context = <String, Object>{
    'plugins': pluginConfigs,
  };
  renderTemplateToFile(
    '''
//
// Generated file. Do not edit.
//

// clang-format off

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
    registryDirectory.childFile('generated_plugin_registrant.h'),
  );
}

void _writeCsharpPluginRegistrant(
  Directory registryDirectory,
  List<TizenPlugin> plugins,
) {
  final List<Map<String, Object?>> pluginConfigs =
      plugins.map((TizenPlugin plugin) => plugin.toMap()).toList();
  final Map<String, Object> context = <String, Object>{
    'plugins': pluginConfigs,
  };
  renderTemplateToFile(
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
    registryDirectory.childFile('GeneratedPluginRegistrant.cs'),
  );
}

/// Source: [_renderTemplateToFile] in `flutter_plugins.dart`
void renderTemplateToFile(String template, Object? context, File file) {
  final String renderedTemplate = globals.templateRenderer
      .renderString(template, context, htmlEscapeValues: false);
  file.createSync(recursive: true);
  file.writeAsStringSync(renderedTemplate);
}
