// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/tizen_project.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:xml/xml.dart';

import '../src/common.dart';
import '../src/context.dart';

void main() {
  late FileSystem fileSystem;
  late TizenProject project;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    project = TizenProject.fromFlutter(
        FlutterProject.fromDirectoryTest(fileSystem.currentDirectory));
  });

  testUsingContext('Can create csproj.user file', () async {
    project.manifestFile.createSync(recursive: true);
    project.editableDirectory
        .childFile('Runner.csproj')
        .createSync(recursive: true);

    final File userFile =
        project.editableDirectory.childFile('Runner.csproj.user');
    expect(userFile, isNot(exists));

    await project.ensureReadyForPlatformSpecificTooling();

    final XmlDocument xmlDocument =
        XmlDocument.parse(userFile.readAsStringSync());
    expect(xmlDocument.findAllElements('FlutterEmbeddingPath'), isNotEmpty);
  });

  testUsingContext('Can update existing csproj.user file', () async {
    project.manifestFile.createSync(recursive: true);
    project.editableDirectory
        .childFile('Runner.csproj')
        .createSync(recursive: true);

    final File userFile = project.editableDirectory
        .childFile('Runner.csproj.user')
      ..writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<Project>
  <PropertyGroup>
    <FlutterEmbeddingPath>/path/to/embedding/project/file</FlutterEmbeddingPath>
  </PropertyGroup>
</Project>
''');

    await project.ensureReadyForPlatformSpecificTooling();

    final XmlDocument xmlDocument =
        XmlDocument.parse(userFile.readAsStringSync());
    expect(
      xmlDocument.findAllElements('FlutterEmbeddingPath').first.text,
      endsWith('Tizen.Flutter.Embedding.csproj'),
    );
  });

  testUsingContext('Can clean C# project', () {
    project.manifestFile.createSync(recursive: true);
    project.editableDirectory
        .childFile('Runner.csproj')
        .createSync(recursive: true);
    expect(project.isDotnet, isTrue);

    final Directory binDir = project.editableDirectory.childDirectory('bin')
      ..createSync(recursive: true);
    final Directory objDir = project.editableDirectory.childDirectory('obj')
      ..createSync(recursive: true);

    project.clean();

    expect(binDir, isNot(exists));
    expect(objDir, isNot(exists));
  });

  testUsingContext('Can clean C++ project', () {
    project.manifestFile.createSync(recursive: true);
    expect(project.isDotnet, isFalse);

    final Directory debugDir = project.editableDirectory.childDirectory('Debug')
      ..createSync(recursive: true);
    final Directory releaseDir = project.editableDirectory
        .childDirectory('Release')
      ..createSync(recursive: true);

    project.clean();

    expect(debugDir, isNot(exists));
    expect(releaseDir, isNot(exists));
  });

  testUsingContext('Can clean multi app project', () {
    project.uiAppDirectory.createSync(recursive: true);
    project.uiManifestFile.createSync(recursive: true);
    project.serviceAppDirectory.createSync(recursive: true);
    project.serviceManifestFile.createSync(recursive: true);
    expect(project.isMultiApp, isTrue);

    final Directory uiDebugDir = project.uiAppDirectory.childDirectory('Debug')
      ..createSync(recursive: true);
    final Directory uiReleaseDir = project.uiAppDirectory
        .childDirectory('Release')
      ..createSync(recursive: true);
    final Directory serviceDebugDir = project.serviceAppDirectory
        .childDirectory('Debug')
      ..createSync(recursive: true);
    final Directory serviceReleaseDir = project.serviceAppDirectory
        .childDirectory('Release')
      ..createSync(recursive: true);

    project.clean();

    expect(uiDebugDir, isNot(exists));
    expect(uiReleaseDir, isNot(exists));
    expect(serviceDebugDir, isNot(exists));
    expect(serviceReleaseDir, isNot(exists));
  });
}
