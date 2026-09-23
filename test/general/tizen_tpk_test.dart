// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_tpk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:xml/xml.dart';

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
    final FlutterProject project = FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);
    fileSystem.file('tizen/tizen-manifest.xml').createSync(recursive: true);

    expect(() => TizenTpk.fromProject(project),
        throwsToolExit(message: 'Failed to parse tizen-manifest.xml'));
  });

  testWithoutContext('TizenManifest.parseFromXml can parse manifest that has no profile value', () {
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

  testUsingContext('TizenManifest.parseFromXml can parse multi-app manifest', () {
    final File xmlFile = fileSystem.file('tizen-manifest.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<manifest package="package_id" version="9.9.9" api-version="4.0">
    <profile name="common"/>
    <ui-application appid="app_id_1" exec="runner" type="capp"/>
    <service-application appid="app_id_2" exec="runner_2" type="capp"/>
    <service-application appid="app_id_3" exec="runner_3" type="capp"/>
</manifest>
''');

    final TizenManifest manifest = TizenManifest.parseFromXml(xmlFile);
    expect(manifest.applicationId, equals('app_id_1'));
    expect(manifest.executables, equals(<String>['runner', 'runner_2', 'runner_3']));
    expect(logger.traceText, contains('tizen-manifest.xml: Found 3 application declarations.'));
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });

  testWithoutContext('Signature.parseFromXml can parse multi-line signature', () {
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

  group('Native window configuration', () {
    late File manifestFile;
    late File configFile;
    const source = '''
<manifest package="package_id" version="1.0.0">
  <ui-application appid="ui" exec="runner" type="flutter"/>
  <service-application appid="service" exec="runner_service" type="flutter"/>
</manifest>
''';

    setUp(() {
      manifestFile = fileSystem.file('tizen-manifest.xml')..writeAsStringSync(source);
      configFile = fileSystem.file('flutter-tizen.yaml');
    });

    testWithoutContext('Absent or empty configuration preserves defaults', () {
      final TizenManifest manifest = TizenManifest.parseFromXml(manifestFile);
      final String original = manifest.toXmlString();
      manifest.applyWindowConfiguration(configFile);
      expect(manifest.toXmlString(), original);
      for (final yaml in <String>['', '{}', 'configuration: {}']) {
        configFile.writeAsStringSync(yaml);
        manifest.applyWindowConfiguration(configFile);
        expect(manifest.toXmlString(), original);
      }
    });

    testWithoutContext('Injects only configured UI properties and preserves the source', () {
      configFile.writeAsStringSync('''
configuration:
  window_offset_x: -20
  window_offset_y: 30
  window_width: 800
  window_height: 600
  transparent: true
  focusable: false
  top_level: true
  user_pixel_ratio: 1.25
  pointing_device_support: false
  floating_menu_support: false
''');
      final TizenManifest manifest = TizenManifest.parseFromXml(manifestFile);
      manifest.applyWindowConfiguration(configFile);
      final XmlElement root = XmlDocument.parse(manifest.toXmlString()).rootElement;
      final values = <String, String?>{
        for (final XmlElement metadata
            in root.findElements('ui-application').single.findElements('metadata'))
          metadata.getAttribute('key')!.split('/').last: metadata.getAttribute('value'),
      };
      expect(values, <String, String>{
        'window_offset_x': '-20',
        'window_offset_y': '30',
        'window_width': '800',
        'window_height': '600',
        'transparent': 'true',
        'focusable': 'false',
        'top_level': 'true',
        'user_pixel_ratio': '1.25',
        'pointing_device_support': 'false',
        'floating_menu_support': 'false',
      });
      expect(root.findElements('service-application').single.findElements('metadata'), isEmpty);
      expect(manifestFile.readAsStringSync(), source);
    });

    testWithoutContext('Rejects malformed configuration and invalid property values', () {
      for (final yaml in <String>[
        '[]',
        'configuration: [',
        'configuration: []',
        'configuration: {window_width: -1}',
        'configuration: {window_height: 1.5}',
        'configuration: {window_offset_x: 2147483648}',
        'configuration: {window_offset_y: -2147483649}',
        'configuration: {transparent: "false"}',
        'configuration: {focusable: 0}',
        'configuration: {user_pixel_ratio: -1}',
        'configuration: {user_pixel_ratio: .nan}',
        'configuration: {user_pixel_ratio: .inf}',
        'configuration: {unknown: true}',
      ]) {
        configFile.writeAsStringSync(yaml);
        final TizenManifest manifest = TizenManifest.parseFromXml(manifestFile);
        expect(() => manifest.applyWindowConfiguration(configFile),
            throwsToolExit(message: 'flutter-tizen.yaml'),
            reason: yaml);
      }
    });
  });
}
