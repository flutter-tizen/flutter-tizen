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
    project =
        TizenProject.fromFlutter(FlutterProject.fromDirectoryTest(fileSystem.currentDirectory));
  });

  testUsingContext('Can create csproj.user file', () async {
    project.manifestFile.createSync(recursive: true);
    project.editableDirectory.childFile('Runner.csproj').createSync(recursive: true);

    final File userFile = project.editableDirectory.childFile('Runner.csproj.user');
    expect(userFile, isNot(exists));

    await project.ensureReadyForPlatformSpecificTooling();

    final xmlDocument = XmlDocument.parse(userFile.readAsStringSync());
    expect(xmlDocument.findAllElements('FlutterEmbeddingPath'), isNotEmpty);
  });

  testUsingContext('Can update existing csproj.user file', () async {
    project.manifestFile.createSync(recursive: true);
    project.editableDirectory.childFile('Runner.csproj').createSync(recursive: true);

    final File userFile = project.editableDirectory.childFile('Runner.csproj.user')
      ..writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<Project>
  <PropertyGroup>
    <FlutterEmbeddingPath>/path/to/embedding/project/file</FlutterEmbeddingPath>
  </PropertyGroup>
</Project>
''');

    await project.ensureReadyForPlatformSpecificTooling();

    final xmlDocument = XmlDocument.parse(userFile.readAsStringSync());
    expect(
      xmlDocument.findAllElements('FlutterEmbeddingPath').first.innerText,
      endsWith('Tizen.Flutter.Embedding.csproj'),
    );
  });

  testUsingContext('Can clean C# project', () {
    project.uiManifestFile.createSync(recursive: true);
    project.uiAppDirectory.childFile('Runner.csproj').createSync(recursive: true);
    project.serviceManifestFile.createSync(recursive: true);
    project.serviceAppDirectory.childFile('Runner.csproj').createSync(recursive: true);
    expect(project.isMultiApp, isTrue);
    expect(project.isDotnet, isTrue);

    final Directory uiBinDir = project.uiAppDirectory.childDirectory('bin')
      ..createSync(recursive: true);
    final Directory uiObjDir = project.uiAppDirectory.childDirectory('obj')
      ..createSync(recursive: true);
    final Directory serviceBinDir = project.serviceAppDirectory.childDirectory('bin')
      ..createSync(recursive: true);
    final Directory serviceObjDir = project.serviceAppDirectory.childDirectory('obj')
      ..createSync(recursive: true);

    project.clean();

    expect(uiBinDir, isNot(exists));
    expect(uiObjDir, isNot(exists));
    expect(serviceBinDir, isNot(exists));
    expect(serviceObjDir, isNot(exists));
  });

  testUsingContext('Can clean C++ project', () {
    project.uiManifestFile.createSync(recursive: true);
    project.serviceManifestFile.createSync(recursive: true);
    expect(project.isMultiApp, isTrue);
    expect(project.isDotnet, isFalse);

    final Directory uiDebugDir = project.uiAppDirectory.childDirectory('Debug')
      ..createSync(recursive: true);
    final Directory uiReleaseDir = project.uiAppDirectory.childDirectory('Release')
      ..createSync(recursive: true);
    final Directory serviceDebugDir = project.serviceAppDirectory.childDirectory('Debug')
      ..createSync(recursive: true);
    final Directory serviceReleaseDir = project.serviceAppDirectory.childDirectory('Release')
      ..createSync(recursive: true);

    project.clean();

    expect(uiDebugDir, isNot(exists));
    expect(uiReleaseDir, isNot(exists));
    expect(serviceDebugDir, isNot(exists));
    expect(serviceReleaseDir, isNot(exists));
  });

  testWithoutContext('Detects apps running on the prebuilt runner', () {
    expect(project.usesPrebuiltRunner, isFalse);

    project.manifestFile
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<manifest package="package_id" version="1.0.0">
    <ui-application appid="app_id" exec="runner" type="capp"/>
</manifest>
''');
    expect(project.usesPrebuiltRunner, isFalse);
    expect(project.managedDirectory.path, endsWith('tizen/flutter'));

    project.manifestFile.writeAsStringSync(
      project.manifestFile.readAsStringSync().replaceFirst('"capp"', '"flutter"'),
    );
    expect(project.usesPrebuiltRunner, isTrue);
    expect(project.managedDirectory.path, endsWith('.dart_tool/tizen'));
    expect(project.appDepsFile.path, endsWith('.dart_tool/tizen/.app.deps.json'));
  });

  testUsingContext('Rejects a manifest mixing type="flutter" with other types', () {
    project.manifestFile
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<manifest package="package_id" version="1.0.0">
    <ui-application appid="app_id" exec="runner" type="flutter"/>
    <service-application appid="app_id_service" exec="runner_service" type="capp"/>
</manifest>
''');
    expect(() => project.usesPrebuiltRunner, throwsToolExit(message: 'mixes type="flutter"'));
  });

  testUsingContext('The application type takes precedence over the project file', () {
    project.editableDirectory.childFile('Runner.csproj').createSync(recursive: true);
    expect(project.isDotnet, isTrue);

    project.manifestFile.writeAsStringSync('''
<manifest package="package_id" version="1.0.0">
    <ui-application appid="app_id" exec="Runner.dll" type="flutter"/>
</manifest>
''');
    expect(project.isDotnet, isFalse);
    expect(project.usesPrebuiltRunner, isTrue);

    project.manifestFile.writeAsStringSync(
      project.manifestFile.readAsStringSync().replaceFirst('"flutter"', '"dotnet"'),
    );
    expect(project.isDotnet, isTrue);
    expect(project.usesPrebuiltRunner, isFalse);

    final Directory binDir = project.editableDirectory.childDirectory('bin')..createSync();
    final Directory debugDir = project.editableDirectory.childDirectory('Debug')..createSync();
    project.clean();
    expect(binDir, isNot(exists));
    expect(debugDir, isNot(exists));

    project.editableDirectory.childFile('Runner.csproj').deleteSync();
    expect(() => project.isDotnet, throwsToolExit(message: 'no .csproj file was found'));
  });
}
