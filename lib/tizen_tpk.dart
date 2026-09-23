// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/application_package.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import 'tizen_project.dart';

/// See: [AndroidApk] in `application_package.dart`
class TizenTpk extends ApplicationPackage implements PrebuiltApplicationPackage {
  TizenTpk({
    required this.applicationPackage,
    required this.manifest,
    this.signature,
  }) : super(id: manifest.packageId);

  static TizenTpk fromTpk(File tpkFile) {
    final FileSystem fs = tpkFile.fileSystem;
    final Directory tempDir = fs.systemTempDirectory.createTempSync();
    try {
      globals.os.unzip(tpkFile, tempDir);
    } on ProcessException {
      throwToolExit(
        'An error occurred while processing a file: ${fs.path.relative(tpkFile.path)}\n'
        'You may delete the file and try again.',
      );
    }

    final File manifestFile = tempDir.childFile('tizen-manifest.xml');
    final File signatureFile = tempDir.childFile('author-signature.xml');

    return TizenTpk(
      applicationPackage: tpkFile,
      manifest: TizenManifest.parseFromXml(manifestFile),
      signature: Signature.parseFromXml(signatureFile),
    );
  }

  static TizenTpk fromProject(FlutterProject flutterProject) {
    final project = TizenProject.fromFlutter(flutterProject);
    if (!project.existsSync()) {
      throwToolExit('This project is not configured for Tizen.');
    }

    final File tpkFile = flutterProject.directory
        .childDirectory('build')
        .childDirectory('tizen')
        .childDirectory('tpk')
        .childFile(project.outputTpkName);
    if (tpkFile.existsSync()) {
      return TizenTpk.fromTpk(tpkFile);
    }

    return TizenTpk(
      applicationPackage: tpkFile,
      manifest: TizenManifest.parseFromXml(project.manifestFile),
    );
  }

  @override
  final FileSystemEntity applicationPackage;

  /// The manifest information.
  final TizenManifest manifest;

  /// The SHA512 signature.
  final Signature? signature;

  /// The application ID.
  String get applicationId => manifest.applicationId;

  @override
  String get name => applicationPackage.basename;

  @override
  String get displayName => id;
}

/// Represents the content of `tizen-manifest.xml` file.
/// https://docs.tizen.org/application/tizen-studio/native-tools/manifest-text-editor
///
/// See: [ApkManifestData] in `application_package.dart`
class TizenManifest {
  TizenManifest(this._document);

  static TizenManifest parseFromXml(File xmlFile) {
    if (!xmlFile.existsSync()) {
      throwToolExit('tizen-manifest.xml could not be found.');
    }

    XmlDocument document;
    try {
      document = XmlDocument.parse(xmlFile.readAsStringSync().trim());
    } on XmlException catch (ex) {
      throwToolExit('Failed to parse tizen-manifest.xml: $ex');
    }

    final XmlElement manifest = document.rootElement;
    if (manifest.getAttribute('package') == null) {
      throwToolExit('No attribute named package found in tizen-manifest.xml.');
    }
    if (manifest.getAttribute('version') == null) {
      throwToolExit('No attribute named version found in tizen-manifest.xml.');
    }
    return TizenManifest(document);
  }

  final XmlDocument _document;

  XmlElement get _manifest => _document.rootElement;

  /// The package name.
  String get packageId => _manifest.getAttribute('package')!;

  /// The package version number in the "x.y.z" format.
  String get version => _manifest.getAttribute('version')!;

  /// The target API version number.
  String? get apiVersion => _manifest.getAttribute('api-version');

  late final XmlElement _profile = () {
    if (_manifest.findElements('profile').isEmpty) {
      final builder = XmlBuilder();
      builder.element(
        'profile',
        attributes: <String, String>{'name': 'common'},
      );
      _manifest.children.insert(0, builder.buildFragment());
    }
    return _manifest.findElements('profile').first;
  }();

  /// The profile name representing the target device type.
  String get profile => _profile.getAttribute('name')!;

  late final Iterable<XmlElement> _applications = () {
    final Iterable<XmlElement> elements = _manifest.children.whereType<XmlElement>().where(
        (XmlElement element) =>
            element.name.local.endsWith('-application') && element.getAttribute('appid') != null);
    if (elements.isEmpty) {
      throwToolExit('Found no *-application element with appid attribute in tizen-manifest.xml.');
    }
    final XmlElement first = elements.first;
    final String tag = first.name.local;
    if (tag != 'ui-application' && tag != 'service-application') {
      globals.printTrace('tizen-manifest.xml: <$tag> is not officially supported.');
    }
    final String appid = first.getAttribute('appid')!;
    if (elements.length > 1) {
      globals.printTrace(
        'tizen-manifest.xml: Found ${elements.length} application declarations. '
        'Using the first one: <$tag appid="$appid">',
      );
    }
    return elements;
  }();

  /// The unique ID used for launching and terminating the application.
  String get applicationId => _applications.first.getAttribute('appid')!;

  /// The application type (either "capp", "dotnet", or "flutter").
  String? get applicationType => _applications.first.getAttribute('type');

  set applicationType(String? type) {
    for (final XmlElement application in _applications) {
      application.setAttribute('type', type);
    }
  }

  /// The executable file names of all applications in the package.
  Iterable<String> get executables =>
      _applications.map((XmlElement app) => app.getAttribute('exec')).whereType<String>();

  /// Adds optional native runner window settings to the packaged UI applications.
  /// The source manifest and the defaults of omitted settings are left intact.
  void applyWindowConfiguration(File configFile) {
    if (!configFile.existsSync()) {
      return;
    }
    Never invalid(String message) => throwToolExit('${configFile.path}: $message');

    Object? yaml;
    try {
      yaml = loadYaml(configFile.readAsStringSync());
    } on YamlException catch (error) {
      invalid('Invalid YAML: $error');
    }
    if (yaml == null) {
      return;
    }
    if (yaml is! YamlMap) {
      invalid('Expected a mapping with an optional configuration section.');
    }
    if (!yaml.containsKey('configuration')) {
      return;
    }
    final Object? configuration = yaml['configuration'];
    if (configuration is! YamlMap) {
      invalid('configuration must be a mapping.');
    }

    final values = <String, String>{};
    for (final MapEntry<Object?, Object?> entry in configuration.entries) {
      final Object? key = entry.key;
      final Object? value = entry.value;
      final bool valid = switch (key) {
        'window_offset_x' ||
        'window_offset_y' =>
          value is int && value >= -2147483648 && value <= 2147483647,
        'window_width' || 'window_height' => value is int && value >= 0 && value <= 2147483647,
        'user_pixel_ratio' => value is num && value.isFinite && value >= 0,
        'transparent' ||
        'focusable' ||
        'top_level' ||
        'pointing_device_support' ||
        'floating_menu_support' =>
          value is bool,
        _ => invalid('Unknown configuration key: $key.'),
      };
      if (!valid) {
        invalid('Invalid value for configuration.$key: $value. '
            'Use booleans for flags, signed 32-bit integers for offsets, '
            'non-negative 32-bit integers for dimensions, and a finite '
            'non-negative number for user_pixel_ratio.');
      }
      values['http://tizen.org/metadata/flutter_tizen/$key'] = value.toString();
    }

    for (final XmlElement application in _manifest.findElements('ui-application')) {
      for (final MapEntry<String, String> entry in values.entries) {
        application.children.removeWhere((XmlNode node) =>
            node is XmlElement &&
            node.name.local == 'metadata' &&
            node.getAttribute('key') == entry.key);
        application.children.add(XmlElement(XmlName('metadata'), <XmlAttribute>[
          XmlAttribute(XmlName('key'), entry.key),
          XmlAttribute(XmlName('value'), entry.value),
        ]));
      }
    }
  }

  String toXmlString() => _document.toXmlString();

  @override
  String toString() => _document.toXmlString(pretty: true);
}

/// Represents the content of `signature1.xml` or `author-signature.xml` file.
class Signature {
  const Signature(this.signatureValue);

  static Signature? parseFromXml(File xmlFile) {
    if (!xmlFile.existsSync()) {
      return null;
    }
    final String data = xmlFile.readAsStringSync().trim();
    if (data.isEmpty) {
      return null;
    }

    XmlDocument document;
    try {
      document = XmlDocument.parse(data);
    } on XmlException catch (ex) {
      globals.printError('Failed to parse ${xmlFile.basename}: $ex');
      return null;
    }

    final Iterable<XmlElement> values = document.rootElement.findElements('SignatureValue');
    if (values.isEmpty) {
      globals.printError('No element named SignatureValue found in ${xmlFile.basename}.');
      return null;
    }
    return Signature(values.first.innerText.replaceAll(RegExp(r'\s+'), ''));
  }

  final String signatureValue;
}
