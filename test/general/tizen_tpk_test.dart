// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_tpk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/project.dart';

import '../src/common.dart';
import '../src/context.dart';

void main() {
  late FileSystem fileSystem;
  late BufferLogger logger;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    logger = BufferLogger.test();
  });

  testWithoutContext('TizenTpk.fromProject fails if manifest is invalid', () {
    final FlutterProject project =
        FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);
    fileSystem.file('tizen/tizen-manifest.xml').createSync(recursive: true);

    expect(() => TizenTpk.fromProject(project),
        throwsToolExit(message: 'Failed to parse tizen-manifest.xml'));
  });

  testWithoutContext(
      'TizenManifest.parseFromXml can parse manifest that has no profile value',
      () {
    final File xmlFile = fileSystem.file('tizen-manifest.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<manifest package="package_id" version="9.9.9" api-version="4.0">
    <ui-application appid="app_id" exec="Runner.dll" type="dotnet"/>
</manifest>
''');

    final TizenManifest manifest = TizenManifest.parseFromXml(xmlFile);
    expect(manifest.packageId, equals('package_id'));
    expect(manifest.version, equals('9.9.9'));
    expect(manifest.apiVersion, equals('4.0'));
    expect(manifest.profile, equals('common'));
    expect(manifest.applicationId, equals('app_id'));
    expect(manifest.applicationType, equals('dotnet'));
  });

  testUsingContext('TizenManifest.parseFromXml can parse multi-app manifest',
      () {
    final File xmlFile = fileSystem.file('tizen-manifest.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<manifest package="package_id" version="9.9.9" api-version="4.0">
    <profile name="common"/>
    <ui-application appid="app_id_1" exec="runner" type="capp"/>
    <service-application appid="app_id_2" exec="runner" type="capp"/>
    <service-application appid="app_id_3" exec="runner" type="capp"/>
</manifest>
''');

    final TizenManifest manifest = TizenManifest.parseFromXml(xmlFile);
    expect(manifest.applicationId, equals('app_id_1'));
    expect(logger.traceText,
        contains('tizen-manifest.xml: Found 3 application declarations.'));
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });

  testWithoutContext('Signature.parseFromXml can parse multi-line signature',
      () {
    final File xmlFile = fileSystem.file('author-signature.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<Signature Id="AuthorSignature">
  <SignatureValue>
AAAA
BBBB
CCCC
  </SignatureValue>
</Signature>
''');

    final Signature? signature = Signature.parseFromXml(xmlFile);
    expect(signature, isNotNull);
    expect(signature!.signatureValue, equals('AAAABBBBCCCC'));
  });
}
