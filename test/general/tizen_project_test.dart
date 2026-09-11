// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/build_targets/utils.dart';
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
    expect(xmlDocument.findAllElements('TizenCoreEnabled'), isNotEmpty);
  });

  testUsingContext('Enables tizen-core for API version 11.0 or later', () async {
    project.editableDirectory.childFile('Runner.csproj').createSync(recursive: true);

    final File userFile = project.editableDirectory.childFile('Runner.csproj.user');

    for (final MapEntry<String, String> entry in <String, String>{
      '6.0': 'false',
      '10.0': 'false',
      '10.1': 'false',
      '11.0': 'true',
      '12.0': 'true',
      '8.0': 'false',
    }.entries) {
      project.manifestFile
        ..createSync(recursive: true)
        ..writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<manifest package="package_id" version="1.0.0" api-version="${entry.key}">
    <profile name="common"/>
</manifest>
''');

      await project.ensureReadyForPlatformSpecificTooling();

      final xmlDocument = XmlDocument.parse(userFile.readAsStringSync());
      expect(
        xmlDocument.findAllElements('TizenCoreEnabled').single.innerText,
        entry.value,
        reason: 'api-version ${entry.key}',
      );
      final propsDocument = XmlDocument.parse(
          project.hostAppRoot.childDirectory('obj').childFile('Flutter.props').readAsStringSync());
      expect(propsDocument.findAllElements('TizenCoreEnabled').single.innerText, entry.value);
      expect(propsDocument.findAllElements('Import').single.getAttribute('Project'),
          endsWith('FlutterApplication.props'));
      expect(propsDocument.findAllElements('TargetFramework'), isEmpty);
      expect(propsDocument.findAllElements('PackageReference'), isEmpty);
      expect(
        getEmbedderArtifactsDirectory(entry.key, 'arm64').basename,
        entry.value == 'true' ? '11.0' : (entry.key == '6.0' ? '6.0' : '6.5'),
      );
      final XmlElement reference = xmlDocument.findAllElements('ProjectReference').single;
      final XmlElement restore =
          xmlDocument.findAllElements('RestoreUseStaticGraphEvaluation').single;
      expect(restore.innerText, 'true');
      expect(restore.getAttribute('Condition'), r"'$(TizenCoreEnabled)' == 'true'");
      expect(xmlDocument.findAllElements('ImportProjectExtensionTargets').single.innerText, 'true');
      expect(reference.getAttribute('Update'), r'@(ProjectReference)');
      expect(
        reference.getAttribute('AdditionalProperties'),
        r'%(ProjectReference.AdditionalProperties);TizenCoreEnabled=$(TizenCoreEnabled)',
      );
    }
  });

  testUsingContext('Generates backend props separately for UI and service apps', () async {
    project.uiAppDirectory.childFile('Runner.csproj').createSync(recursive: true);
    project.serviceAppDirectory.childFile('RunnerService.csproj').createSync(recursive: true);
    project.uiManifestFile
        .writeAsStringSync('<manifest package="ui" version="1.0.0" api-version="11.0"/>');
    project.serviceManifestFile
        .writeAsStringSync('<manifest package="service" version="1.0.0" api-version="6.0"/>');

    await project.ensureReadyForPlatformSpecificTooling();

    for (final directory in <Directory>[
      project.uiAppDirectory,
      project.serviceAppDirectory,
    ]) {
      final props = XmlDocument.parse(
          directory.childDirectory('obj').childFile('Flutter.props').readAsStringSync());
      expect(props.findAllElements('TizenCoreEnabled').single.innerText,
          directory.path == project.uiAppDirectory.path ? 'true' : 'false');
    }
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
}
