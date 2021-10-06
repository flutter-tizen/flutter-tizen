// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/cache.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:flutter_tools/src/commands/clean.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:xml/xml.dart';

import 'tizen_plugins.dart';
import 'tizen_tpk.dart';

/// Source: [WindowsProject] in `cmake_project.dart`
class TizenProject extends FlutterProjectPlatform {
  TizenProject.fromFlutter(this.parent);

  final FlutterProject parent;

  @override
  String get pluginConfigKey => TizenPlugin.kConfigKey;

  Directory get editableDirectory => parent.directory.childDirectory('tizen');

  /// The directory in the project that is managed by Flutter. As much as
  /// possible, files that are edited by Flutter tooling after initial project
  /// creation should live here.
  Directory get managedDirectory => editableDirectory.childDirectory('flutter');

  /// The subdirectory of [managedDirectory] that contains files that are
  /// generated on the fly. All generated files that are not intended to be
  /// checked in should live here.
  Directory get ephemeralDirectory =>
      managedDirectory.childDirectory('ephemeral');

  bool get isDotnet =>
      editableDirectory.childFile('Runner.csproj').existsSync();

  bool get isMultiApp =>
      uiAppDirectory.existsSync() && serviceAppDirectory.existsSync();

  Directory get uiAppDirectory => editableDirectory.childDirectory('ui');
  Directory get serviceAppDirectory =>
      editableDirectory.childDirectory('service');

  File get uiManifestFile => uiAppDirectory.childFile('tizen-manifest.xml');
  File get serviceManifestFile =>
      serviceAppDirectory.childFile('tizen-manifest.xml');

  File get manifestFile => isMultiApp
      ? uiManifestFile
      : editableDirectory.childFile('tizen-manifest.xml');

  @override
  bool existsSync() => isMultiApp
      ? uiManifestFile.existsSync() && serviceManifestFile.existsSync()
      : manifestFile.existsSync();

  String get outputTpkName {
    final TizenManifest manifest = TizenManifest.parseFromXml(manifestFile);
    return '${manifest.packageId}-${manifest.version}.tpk';
  }

  Future<void> ensureReadyForPlatformSpecificTooling() async {
    if (!existsSync() || !isDotnet) {
      return;
    }

    final File userFile = editableDirectory.childFile('Runner.csproj.user');
    const String initialXmlContent = '''
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="Current" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup />
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

    final File embeddingProjectFile = editableDirectory.fileSystem
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('embedding')
        .childDirectory('csharp')
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

  void clean() {
    if (!existsSync()) {
      return;
    }
    _deleteFile(managedDirectory);

    if (isDotnet) {
      _deleteFile(editableDirectory.childDirectory('bin'));
      _deleteFile(editableDirectory.childDirectory('obj'));
      _deleteFile(editableDirectory.childFile('Runner.csproj.user'));
    } else {
      if (isMultiApp) {
        _deleteFile(uiAppDirectory.childDirectory('Debug'));
        _deleteFile(uiAppDirectory.childDirectory('Release'));
        _deleteFile(serviceAppDirectory.childDirectory('Debug'));
        _deleteFile(serviceAppDirectory.childDirectory('Release'));
      } else {
        _deleteFile(editableDirectory.childDirectory('Debug'));
        _deleteFile(editableDirectory.childDirectory('Release'));
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
