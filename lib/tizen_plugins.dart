// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_system/targets/web.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/dart/language_version.dart';
import 'package:flutter_tools/src/dart/package_map.dart';
import 'package:flutter_tools/src/flutter_plugins.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/platform_plugins.dart';
import 'package:flutter_tools/src/plugins.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:package_config/package_config.dart';
import 'package:yaml/yaml.dart';

import 'tizen_project.dart';
import 'tizen_sdk.dart';

/// Constant for 'namespace' key in plugin maps.
const String kNamespace = 'namespace';

/// Constant for 'fileName' key in plugin maps.
const String kFileName = 'fileName';

/// Constant for 'filePath' key in plugin maps.
const String kFilePath = 'filePath';

/// Constant for 'libName' key in plugin maps.
const String kLibName = 'libName';

/// Contains the parameters to template a Tizen plugin.
///
/// The [name] of the plugin is required. Either [dartPluginClass] or
/// [pluginClass] are required. [pluginClass] will be the entry point to the
/// plugin's native code. If [pluginClass] is not empty, the [fileName]
/// containing the plugin's code is required. If the plugin is written in C#,
/// the [namespace] is required and the [fileName] should be the name of
/// the project file (e.g. "MyPlugin.csproj").
///
/// Source: [LinuxPlugin] in `platform_plugins.dart`
class TizenPlugin extends PluginPlatform implements NativeOrDartPlugin {
  TizenPlugin({
    required this.name,
    required this.directory,
    this.namespace,
    this.pluginClass,
    this.dartPluginClass,
    this.fileName,
  }) : assert(pluginClass != null || dartPluginClass != null);

  static TizenPlugin fromYaml(String name, Directory directory, YamlMap yaml) {
    assert(validate(yaml));
    return TizenPlugin(
      name: name,
      directory: directory,
      namespace: yaml[kNamespace] as String?,
      pluginClass: yaml[kPluginClass] as String?,
      dartPluginClass: yaml[kDartPluginClass] as String?,
      fileName: yaml[kFileName] as String?,
    );
  }

  static bool validate(YamlMap yaml) {
    return yaml[kPluginClass] is String || yaml[kDartPluginClass] is String;
  }

  static const String kConfigKey = 'tizen';

  final String name;
  final Directory directory;
  final String? namespace;
  final String? pluginClass;
  final String? dartPluginClass;
  final String? fileName;

  @override
  bool hasMethodChannel() => pluginClass != null;

  @override
  bool hasFfi() => hasDart();

  @override
  bool hasDart() => dartPluginClass != null;

  bool isDotnet() => fileName?.endsWith('.csproj') ?? false;

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      if (namespace != null) kNamespace: namespace,
      if (pluginClass != null) kPluginClass: pluginClass,
      if (dartPluginClass != null) kDartPluginClass: dartPluginClass,
      if (fileName != null) kFileName: fileName,
      if (fileName != null) kFilePath: directory.childFile(fileName!).path,
      if (libName != null) kLibName: isSharedLib ? libName : 'flutter_plugins',
    };
  }

  File get projectFile => directory.childFile('project_def.prop');

  late final Map<String, String> _projectProperties = () {
    return parseIniFile(projectFile);
  }();

  bool get isSharedLib => _projectProperties['type'] == 'sharedLib';

  String? get libName => _projectProperties['APPNAME']?.toLowerCase();
}

/// Any [FlutterCommand] that references [targetFile] should extend this mixin
/// to ensure that `generated_main.dart` is created and updated properly.
///
/// See: [FlutterCommand.verifyThenRunCommand] in `flutter_command.dart`
mixin DartPluginRegistry on FlutterCommand {
  String? _targetFile;

  bool get _usesTargetOption => argParser.options.containsKey('target');

  @override
  Future<FlutterCommandResult> verifyThenRunCommand(String? commandPath) async {
    final FlutterProject project = FlutterProject.current();
    final TizenProject tizenProject = TizenProject.fromFlutter(project);
    if (_usesTargetOption && tizenProject.existsSync() && !project.isPlugin) {
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

/// Finds entry point functions annotated with `@pragma('vm:entry-point')`
/// from [dartFile] and returns their names.
List<String> _findDartEntrypoints(File dartFile) {
  final String path = dartFile.absolute.path;
  final String dartSdkPath =
      globals.artifacts!.getArtifactPath(Artifact.engineDartSdkPath);
  final AnalysisContextCollection collection = AnalysisContextCollection(
    includedPaths: <String>[path],
    sdkPath: dartSdkPath,
  );
  final AnalysisContext context = collection.contextFor(path);
  final SomeParsedUnitResult parsed =
      context.currentSession.getParsedUnit(path);
  final List<String> names = <String>['main'];
  if (parsed is ParsedUnitResult) {
    for (final FunctionDeclaration function
        in parsed.unit.declarations.whereType<FunctionDeclaration>()) {
      if (function.name.lexeme == 'main') {
        continue;
      }
      for (final Annotation annotation in function.metadata) {
        if (annotation.name.name != 'pragma') {
          continue;
        }
        final ArgumentList? arguments = annotation.arguments;
        if (arguments != null &&
            arguments.arguments.isNotEmpty &&
            arguments.arguments.first.toSource().contains('vm:entry-point')) {
          names.add(function.name.lexeme);
        }
      }
    }
  }
  return names;
}

const String _generatedMainTemplate = '''
//
// Generated file. Do not edit.
//
// @dart = {{dartLanguageVersion}}

// ignore_for_file: avoid_classes_with_only_static_members
// ignore_for_file: avoid_private_typedef_functions
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: directives_ordering
// ignore_for_file: lines_longer_than_80_chars
// ignore_for_file: unnecessary_cast
// ignore_for_file: unused_import

import '{{mainImport}}' as entrypoint;
{{#plugins}}
import 'package:{{name}}/{{name}}.dart';
{{/plugins}}
import 'package:flutter/src/dart_plugin_registrant.dart';

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

{{#dartEntrypoints}}
@pragma('vm:entry-point')
void {{name}}(List<String> args) {
  if (entrypoint.{{name}} is _UnaryFunction) {
    (entrypoint.{{name}} as _UnaryFunction)(args);
  } else {
    (entrypoint.{{name}} as _NullaryFunction)();
  }
}
{{/dartEntrypoints}}
''';

/// See:
/// - [WebEntrypointTarget.build] in `web.dart`
/// - [generateMainDartWithPluginRegistrant] in `flutter_plugins.dart`
Future<void> _generateEntrypointWithPluginRegistrant(
  FlutterProject project,
  File mainFile,
  File newMainFile,
) async {
  // To avoid any conflict, ensure that a registrant file generated by
  // DartPluginRegistrantTarget is not present when building a Tizen app.
  // Issue: https://github.com/flutter-tizen/plugins/issues/341
  if (project.dartPluginRegistrant.existsSync()) {
    project.dartPluginRegistrant.deleteSync();
  }

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
  final List<String> dartEntrypoints = _findDartEntrypoints(mainFile);
  final List<TizenPlugin> dartPlugins =
      await findTizenPlugins(project, dartOnly: true);

  final Map<String, Object> context = <String, Object>{
    'mainImport': mainUri.toString(),
    'dartLanguageVersion': languageVersion.toString(),
    'dartEntrypoints':
        dartEntrypoints.map((String name) => <String, String>{'name': name}),
    'plugins': dartPlugins.map((TizenPlugin plugin) => plugin.toMap()),
  };
  renderTemplateToFile(
    _generatedMainTemplate,
    context,
    newMainFile,
  );
}

/// https://github.com/flutter-tizen/plugins
const List<String> _kKnownPlugins = <String>[
  'audioplayers',
  'battery_plus',
  'camera',
  'connectivity_plus',
  'device_info_plus',
  'flutter_app_badger',
  'flutter_secure_storage',
  'flutter_tts',
  'geolocator',
  'google_maps_flutter',
  'google_sign_in',
  'image_picker',
  'integration_test',
  'network_info_plus',
  'package_info_plus',
  'path_provider',
  'permission_handler',
  'sensors_plus',
  'shared_preferences',
  'sqflite',
  'url_launcher',
  'wakelock',
];

/// This function is expected to be called whenever
/// [FlutterProject.ensureReadyForPlatformSpecificTooling] is called.
///
/// See: [FlutterProject.ensureReadyForPlatformSpecificTooling] in `project.dart`
Future<void> ensureReadyForTizenTooling(FlutterProject project) async {
  if (!project.directory.existsSync() || project.isPlugin) {
    return;
  }
  final TizenProject tizenProject = TizenProject.fromFlutter(project);
  await tizenProject.ensureReadyForPlatformSpecificTooling();

  await _ensurePluginsReadyForTizenTooling(project);
  await injectTizenPlugins(project);
  await _informAvailableTizenPlugins(project);
}

Future<void> _ensurePluginsReadyForTizenTooling(FlutterProject project) async {
  final List<TizenPlugin> dotnetPlugins =
      await findTizenPlugins(project, dotnetOnly: true);
  for (final TizenPlugin plugin in dotnetPlugins) {
    final File? projectFile = findDotnetProjectFile(plugin.directory);
    if (projectFile != null) {
      updateDotnetUserProjectFile(projectFile);
    }
  }
}

/// See: [injectPlugins] in `flutter_plugins.dart`
Future<void> injectTizenPlugins(FlutterProject project) async {
  final TizenProject tizenProject = TizenProject.fromFlutter(project);
  if (tizenProject.existsSync()) {
    final List<TizenPlugin> cppPlugins =
        await findTizenPlugins(project, cppOnly: true);
    final List<TizenPlugin> dotnetPlugins =
        await findTizenPlugins(project, dotnetOnly: true);
    _writeTizenPluginRegistrant(tizenProject, cppPlugins, dotnetPlugins);
    if (tizenProject.isDotnet) {
      _writeIntermediateDotnetFiles(tizenProject, dotnetPlugins);
    }
  }
}

Future<void> _informAvailableTizenPlugins(FlutterProject project) async {
  final List<String> plugins =
      (await findPlugins(project)).map((Plugin p) => p.name).toList();
  for (final String plugin in plugins) {
    final String tizenPlugin = '${plugin}_tizen';
    if (_kKnownPlugins.contains(plugin) && !plugins.contains(tizenPlugin)) {
      globals.printWarning(
          '$tizenPlugin is available on pub.dev. Did you forget to add to pubspec.yaml?');
    }
  }
}

/// Source: [findPlugins] in `flutter_plugins.dart`
Future<List<TizenPlugin>> findTizenPlugins(
  FlutterProject project, {
  bool dartOnly = false,
  bool cppOnly = false,
  bool dotnetOnly = false,
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
    } else if (dartOnly && !plugin.hasDart()) {
      continue;
    } else if (cppOnly && (!plugin.hasMethodChannel() || plugin.isDotnet())) {
      continue;
    } else if (dotnetOnly &&
        (!plugin.hasMethodChannel() || !plugin.isDotnet())) {
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

const String _cppPluginRegistryTemplate = '''
//
// Generated file. Do not edit.
//

// clang-format off

#ifndef GENERATED_PLUGIN_REGISTRANT_
#define GENERATED_PLUGIN_REGISTRANT_

#include <flutter/plugin_registry.h>

{{#cppPlugins}}
#include "{{fileName}}"
{{/cppPlugins}}

// Registers Flutter plugins.
void RegisterPlugins(flutter::PluginRegistry *registry) {
{{#cppPlugins}}
  {{pluginClass}}RegisterWithRegistrar(
      registry->GetRegistrarForPlugin("{{pluginClass}}"));
{{/cppPlugins}}
}

#endif  // GENERATED_PLUGIN_REGISTRANT_
''';

const String _csharpPluginRegistryTemplate = '''
//
// Generated file. Do not edit.
//

using System;
using System.Runtime.InteropServices;
using Tizen.Flutter.Embedding;

internal class GeneratedPluginRegistrant
{
  {{#cppPlugins}}
    [DllImport("{{libName}}.so")]
    public static extern void {{pluginClass}}RegisterWithRegistrar(
        FlutterDesktopPluginRegistrar registrar);

  {{/cppPlugins}}
    public static void RegisterPlugins(IPluginRegistry registry)
    {
      {{#cppPlugins}}
        {{pluginClass}}RegisterWithRegistrar(
            registry.GetRegistrarForPlugin("{{pluginClass}}"));
      {{/cppPlugins}}
      {{#dotnetPlugins}}
        DotnetPluginRegistry.Instance.AddPlugin(
            new global::{{namespace}}.{{pluginClass}}());
      {{/dotnetPlugins}}
    }
}
''';

/// See: [writeWindowsPluginFiles] in `flutter_plugins.dart`
void _writeTizenPluginRegistrant(
  TizenProject project,
  List<TizenPlugin> cppPlugins,
  List<TizenPlugin> dotnetPlugins,
) {
  final Map<String, Object> context = <String, Object>{
    'cppPlugins': cppPlugins.map((TizenPlugin plugin) => plugin.toMap()),
    'dotnetPlugins': dotnetPlugins.map((TizenPlugin plugin) => plugin.toMap()),
  };

  if (project.isDotnet) {
    renderTemplateToFile(
      _csharpPluginRegistryTemplate,
      context,
      project.managedDirectory.childFile('GeneratedPluginRegistrant.cs'),
    );
  } else {
    renderTemplateToFile(
      _cppPluginRegistryTemplate,
      context,
      project.managedDirectory.childFile('generated_plugin_registrant.h'),
    );
  }
}

// Reserved for future use.
const String _intermediateDotnetPropsTemplate = '''
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<Project ToolsVersion="14.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
</Project>
''';

const String _intermediateDotnetTargetsTemplate = '''
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<Project ToolsVersion="14.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
  {{#dotnetPlugins}}
    <ProjectReference Include="{{filePath}}" />
  {{/dotnetPlugins}}
  </ItemGroup>
</Project>
''';

void _writeIntermediateDotnetFiles(
  TizenProject project,
  List<TizenPlugin> dotnetPlugins,
) {
  final String projectFileName = project.projectFile!.basename;
  final Map<String, Object> context = <String, Object>{
    'dotnetPlugins': dotnetPlugins.map((TizenPlugin plugin) => plugin.toMap()),
  };
  renderTemplateToFile(
    _intermediateDotnetPropsTemplate,
    context,
    project.intermediateDirectory.childFile('$projectFileName.flutter.props'),
  );
  renderTemplateToFile(
    _intermediateDotnetTargetsTemplate,
    context,
    project.intermediateDirectory.childFile('$projectFileName.flutter.targets'),
  );
}

/// Source: [_renderTemplateToFile] in `flutter_plugins.dart`
void renderTemplateToFile(String template, Object? context, File file) {
  final String renderedTemplate =
      globals.templateRenderer.renderString(template, context);
  file.createSync(recursive: true);
  file.writeAsStringSync(renderedTemplate);
}
