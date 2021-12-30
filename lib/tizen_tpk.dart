// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/application_package.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:xml/xml.dart';

import 'tizen_project.dart';

/// See: [AndroidApk] in `application_package.dart`
class TizenTpk extends ApplicationPackage {
  TizenTpk({
    required this.file,
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

    // We have to manually restore permissions for files zipped by
    // build-task-tizen on Unix.
    // Issue: https://github.com/dotnet/runtime/issues/1548
    tempDir.listSync().whereType<File>().forEach((File file) {
      globals.os.chmod(file, '644');
    });

    final File manifestFile = tempDir.childFile('tizen-manifest.xml');
    final File signatureFile = tempDir.childFile('author-signature.xml');

    return TizenTpk(
      file: tpkFile,
      manifest: TizenManifest.parseFromXml(manifestFile),
      signature: Signature.parseFromXml(signatureFile),
    );
  }

  static TizenTpk fromProject(FlutterProject flutterProject) {
    final TizenProject project = TizenProject.fromFlutter(flutterProject);

    final File tpkFile = flutterProject.directory
        .childDirectory('build')
        .childDirectory('tizen')
        .childDirectory('tpk')
        .childFile(project.outputTpkName);
    if (tpkFile.existsSync()) {
      return TizenTpk.fromTpk(tpkFile);
    }

    return TizenTpk(
      file: tpkFile,
      manifest: TizenManifest.parseFromXml(project.manifestFile),
    );
  }

  /// The path to the TPK file.
  final File file;

  /// The manifest information.
  final TizenManifest manifest;

  /// The SHA512 signature.
  final Signature? signature;

  /// The application ID.
  String get applicationId => manifest.applicationId;

  /// Whether the application is a .NET application.
  bool get isDotnet => manifest.applicationType == 'dotnet';

  @override
  String get name => file.basename;

  @override
  String get displayName => id;

  @override
  File get packagesFile => file;
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
  set version(String value) => _manifest.setAttribute('version', value);

  /// The target API version number.
  String get apiVersion => _manifest.getAttribute('api-version') ?? '4.0';

  late final XmlElement _profile = () {
    if (_manifest.findElements('profile').isEmpty) {
      final XmlBuilder builder = XmlBuilder();
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
  set profile(String value) => _profile.setAttribute('name', value);

  late final Iterable<XmlElement> _applications = () {
    final Iterable<XmlElement> elements = _manifest.children
        .whereType<XmlElement>()
        .where((XmlElement element) =>
            element.name.local.endsWith('-application') &&
            element.getAttribute('appid') != null);
    if (elements.isEmpty) {
      throwToolExit(
          'Found no *-application element with appid attribute in tizen-manifest.xml.');
    }
    final XmlElement first = elements.first;
    final String tag = first.name.local;
    if (tag != 'ui-application' && tag != 'service-application') {
      globals.printTrace(
          'tizen-manifest.xml: <$tag> is not officially supported.');
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

  /// The application type (either "capp" or "dotnet").
  String? get applicationType => _applications.first.getAttribute('type');

  @override
  String toString() => _document.toXmlString(pretty: true, indent: '    ');
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

    final Iterable<XmlElement> values =
        document.rootElement.findElements('SignatureValue');
    if (values.isEmpty) {
      globals.printError(
          'No element named SignatureValue found in ${xmlFile.basename}.');
      return null;
    }
    return Signature(values.first.text.replaceAll(RegExp(r'\s+'), ''));
  }

  final String signatureValue;
}
