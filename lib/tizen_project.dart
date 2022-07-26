// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/bundle.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/clean.dart';
import 'package:flutter_tools/src/flutter_manifest.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/template.dart';
import 'package:meta/meta.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import 'tizen_plugins.dart';
import 'tizen_tpk.dart';

/// Source: [WindowsProject] in `cmake_project.dart`
class TizenProject extends FlutterProjectPlatform {
  TizenProject.fromFlutter(this.parent);

  final FlutterProject parent;

  /// See: [FlutterManifest] in `flutter_manifest.xml`
  late final Map<String, Object?> _parentPubspec = () {
    final File manifestFile = parent.directory.childFile(defaultManifestPath);
    if (!manifestFile.existsSync()) {
      return <String, Object?>{};
    }
    YamlMap? yamlMap;
    try {
      yamlMap = loadYaml(manifestFile.readAsStringSync()) as YamlMap?;
    } on YamlException {
      return <String, Object?>{};
    }
    return yamlMap?.cast<String, Object?>() ?? <String, Object?>{};
  }();

  @override
  String get pluginConfigKey => TizenPlugin.kConfigKey;

  Directory get editableDirectory => parent.directory.childDirectory('tizen');
  Directory get _ephemeralModuleDirectory =>
      parent.directory.childDirectory('.tizen');

  Directory get hostAppRoot {
    if (!parent.isModule || editableDirectory.existsSync()) {
      return isMultiApp ? uiAppDirectory : editableDirectory;
    }
    return _ephemeralModuleDirectory;
  }

  /// The directory in the project that is managed by Flutter. As much as
  /// possible, files that are edited by Flutter tooling after initial project
  /// creation should live here.
  Directory get managedDirectory => hostAppRoot.childDirectory('flutter');

  /// The subdirectory of [managedDirectory] that contains files that are
  /// generated on the fly. All generated files that are not intended to be
  /// checked in should live here.
  Directory get ephemeralDirectory =>
      managedDirectory.childDirectory('ephemeral');

  /// The intermediate output directory in the project that is managed by dotnet.
  Directory get intermediateDirectory => hostAppRoot.childDirectory('obj');

  bool get isMultiApp =>
      uiAppDirectory.existsSync() && serviceAppDirectory.existsSync();

  @visibleForTesting
  Directory get uiAppDirectory => editableDirectory.childDirectory('ui');

  @visibleForTesting
  Directory get serviceAppDirectory =>
      editableDirectory.childDirectory('service');

  // TODO(swift-kim): Add @visibleForTesting to these.
  File get uiManifestFile => uiAppDirectory.childFile('tizen-manifest.xml');
  File get serviceManifestFile =>
      serviceAppDirectory.childFile('tizen-manifest.xml');

  File get manifestFile => hostAppRoot.childFile('tizen-manifest.xml');

  @override
  bool existsSync() => hostAppRoot.existsSync();

  File? get projectFile {
    final File? csprojFile = findDotnetProjectFile(hostAppRoot);
    if (csprojFile != null) {
      return csprojFile;
    }
    final File projectDef = hostAppRoot.childFile('project_def.prop');
    return projectDef.existsSync() ? projectDef : null;
  }

  bool get isDotnet => projectFile?.basename.endsWith('.csproj') ?? false;

  String? get _tizenLanguage {
    if (parent.isModule) {
      final Object? flutterDescriptor = _parentPubspec['flutter'];
      if (flutterDescriptor is YamlMap) {
        final Object? module = flutterDescriptor['module'];
        if (module is YamlMap) {
          final Object? tizenLanguage = module['tizenLanguage'];
          if (tizenLanguage is String) {
            return tizenLanguage;
          }
        }
      }
    }
    return null;
  }

  String get outputTpkName {
    final TizenManifest manifest = TizenManifest.parseFromXml(manifestFile);
    return '${manifest.packageId}-${manifest.version}.tpk';
  }

  /// See: [AndroidProject.ensureReadyForPlatformSpecificTooling] in `project.dart`
  Future<void> ensureReadyForPlatformSpecificTooling() async {
    if (parent.isModule && !existsSync()) {
      // TODO(swift-kim): Regenerate from template if the project type and
      // language do not match. Beware that files in "tizen/" should not be
      // overwritten.
      await _overwriteFromTemplate(
        globals.fs.path.join('module', _tizenLanguage ?? 'cpp'),
        hostAppRoot,
      );
    }
    if (existsSync() && isDotnet) {
      updateDotnetUserProjectFile(projectFile!);
    }
  }

  /// Source: [AndroidProject._overwriteFromTemplate] in `project.dart`
  Future<void> _overwriteFromTemplate(String path, Directory target) async {
    final Template template = await Template.fromName(
      // Relative to "flutter_tools/templates/".
      globals.fs.path.join('..', '..', '..', '..', 'templates', path),
      fileSystem: globals.fs,
      templateManifest: null,
      logger: globals.logger,
      templateRenderer: globals.templateRenderer,
    );
    final String androidIdentifier = parent.manifest.androidPackage ??
        'com.example.${parent.manifest.appName}';
    template.render(
      target,
      <String, Object>{
        'projectName': parent.manifest.appName,
        'tizenIdentifier': androidIdentifier,
      },
      printStatusWhenWriting: false,
    );
  }

  void clean() {
    if (!existsSync()) {
      return;
    }
    _deleteFile(_ephemeralModuleDirectory);
    _deleteFile(managedDirectory);

    if (isDotnet) {
      _deleteFile(hostAppRoot.childDirectory('bin'));
      _deleteFile(hostAppRoot.childDirectory('obj'));
    } else {
      _deleteFile(hostAppRoot.childDirectory('Debug'));
      _deleteFile(hostAppRoot.childDirectory('Release'));
      if (isMultiApp) {
        _deleteFile(serviceAppDirectory.childDirectory('Debug'));
        _deleteFile(serviceAppDirectory.childDirectory('Release'));
      }
    }
  }

  /// Source: [CleanCommand.deleteFile] in `clean.dart` (simplified)
  void _deleteFile(FileSystemEntity file) {
    if (!file.existsSync()) {
      return;
    }
    final String path = file.fileSystem.path.relative(file.path);
    final Status status = globals.logger.startProgress(
      'Deleting $path...',
    );
    try {
      file.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      globals.printError('Failed to remove $path: $error');
    } finally {
      status.stop();
    }
  }
}

File? findDotnetProjectFile(Directory directory) {
  for (final File file in directory.listSync().whereType<File>()) {
    if (file.path.endsWith('.csproj')) {
      return file;
    }
  }
  return null;
}

void updateDotnetUserProjectFile(File projectFile) {
  final File userFile =
      projectFile.parent.childFile('${projectFile.basename}.user');
  const String initialXmlContent = '''
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="Current" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
</Project>
''';
  if (!userFile.existsSync()) {
    userFile.writeAsStringSync(initialXmlContent);
  }

  XmlDocument document;
  try {
    document = XmlDocument.parse(userFile.readAsStringSync().trim());
  } on XmlException {
    globals.printStatus('Overwriting ${userFile.basename}...');
    document = XmlDocument.parse(initialXmlContent);
  }

  final File embeddingProjectFile = globals.fs
      .directory(Cache.flutterRoot)
      .parent
      .childDirectory('embedding')
      .childDirectory('csharp')
      .childDirectory('Tizen.Flutter.Embedding')
      .childFile('Tizen.Flutter.Embedding.csproj');
  final Iterable<XmlElement> elements =
      document.findAllElements('FlutterEmbeddingPath');
  if (elements.isEmpty) {
    // Create an element if not exists.
    final XmlBuilder builder = XmlBuilder();
    builder.element('PropertyGroup', nest: () {
      builder.element(
        'FlutterEmbeddingPath',
        nest: embeddingProjectFile.absolute.path,
      );
    });
    document.rootElement.children.add(builder.buildFragment());
  } else {
    // Update existing element(s).
    for (final XmlElement element in elements) {
      element.innerText = embeddingProjectFile.absolute.path;
    }
  }
  userFile.writeAsStringSync(
    document.toXmlString(pretty: true, indent: '  '),
  );
}
