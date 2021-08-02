// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/android/application_package.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/base/user_messages.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/flutter_application_package.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';
import 'package:xml/xml.dart';

import 'tizen_project.dart';

/// [FlutterApplicationPackageFactory] extended for Tizen.
class TizenApplicationPackageFactory extends FlutterApplicationPackageFactory {
  TizenApplicationPackageFactory({
    @required AndroidSdk androidSdk,
    @required ProcessManager processManager,
    @required Logger logger,
    @required UserMessages userMessages,
    @required FileSystem fileSystem,
  }) : super(
          androidSdk: androidSdk,
          processManager: processManager,
          logger: logger,
          userMessages: userMessages,
          fileSystem: fileSystem,
        );

  @override
  Future<ApplicationPackage> getPackageForPlatform(
    TargetPlatform platform, {
    BuildInfo buildInfo,
    File applicationBinary,
  }) async {
    if (platform == TargetPlatform.tester) {
      return applicationBinary == null
          ? await TizenTpk.fromProject(FlutterProject.current())
          : await TizenTpk.fromTpk(applicationBinary);
    }
    return super.getPackageForPlatform(platform,
        buildInfo: buildInfo, applicationBinary: applicationBinary);
  }
}

/// See: [AndroidApk] in `application_package.dart`
class TizenTpk extends ApplicationPackage {
  TizenTpk({
    @required this.file,
    @required this.manifest,
    this.signature,
  })  : assert(file != null),
        assert(manifest != null),
        super(id: manifest.packageId);

  static Future<TizenTpk> fromTpk(File tpkFile) async {
    final Directory tempDir = globals.fs.systemTempDirectory.createTempSync();
    try {
      globals.os.unzip(tpkFile, tempDir);
    } on ProcessException {
      throwToolExit(
        'An error occurred while processing a file: ${globals.fs.path.relative(tpkFile.path)}\n'
        'You may delete the file and try again.',
      );
    }

    // We have to manually restore permissions for files zipped by
    // build-task-tizen on Unix.
    // Issue: https://github.com/dotnet/runtime/issues/1548
    await tempDir.list(recursive: true).forEach((FileSystemEntity entity) {
      if (entity is File) {
        globals.os.chmod(entity, '644');
      }
    });

    final File manifestFile = tempDir.childFile('tizen-manifest.xml');
    final File signatureFile = tempDir.childFile('author-signature.xml');

    return TizenTpk(
      file: tpkFile,
      manifest: TizenManifest.parseFromXml(manifestFile),
      signature: Signature.parseFromXml(signatureFile),
    );
  }

  static Future<TizenTpk> fromProject(FlutterProject flutterProject) async {
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
  final Signature signature;

  /// The application id if applicable.
  String get applicationId => manifest.applicationId;

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
  TizenManifest(this._document) : applicationId = _findApplicationId(_document);

  static TizenManifest parseFromXml(File xmlFile) {
    if (xmlFile == null || !xmlFile.existsSync()) {
      throwToolExit('tizen-manifest.xml could not be found.');
    }

    XmlDocument document;
    try {
      document = XmlDocument.parse(xmlFile.readAsStringSync().trim());
    } on XmlException catch (ex) {
      throwToolExit('Failed to parse ${xmlFile.basename}: $ex');
    }

    return TizenManifest(document);
  }

  final XmlDocument _document;

  XmlElement get _manifest => _document.rootElement;

  /// The unique application id used for launching and terminating applications.
  final String applicationId;

  /// The package name.
  String get packageId => _manifest.getAttribute('package');

  /// The package version number in the "x.y.z" format.
  String get version => _manifest.getAttribute('version');
  set version(String value) => _manifest.setAttribute('version', value);

  /// The target API version number.
  String get apiVersion => _manifest.getAttribute('api-version') ?? '4.0';

  XmlElement get _profile {
    if (_manifest.findElements('profile').isEmpty) {
      final XmlBuilder builder = XmlBuilder();
      builder.element(
        'profile',
        attributes: <String, String>{'name': 'common'},
      );
      _manifest.children.insert(0, builder.buildFragment());
    }
    return _manifest.findElements('profile').first;
  }

  /// The profile name representing the device type.
  String get profile => _profile.getAttribute('name');
  set profile(String value) => _profile.setAttribute('name', value);

  static String _findApplicationId(XmlDocument _document) {
    int count = 0;
    String tag, applicationId;
    for (final XmlNode child in _document.rootElement.children.where(
        (XmlNode n) =>
            n.nodeType == XmlNodeType.ELEMENT &&
            (n as XmlElement).name.local.endsWith('-application'))) {
      final XmlElement element = child as XmlElement;
      ++count;
      if (applicationId == null) {
        tag = element.name.local;
        applicationId = element.getAttribute('appid');
      }
    }
    if (applicationId == null) {
      throwToolExit('Found no *-application element with appid attribute'
          ' in tizen-manifest.xml.');
    }
    if (!_warningShown) {
      if (count > 1) {
        globals.printStatus(
          'Warning: tizen-manifest.xml: Found $count application declarations.'
          ' Using the first one: <$tag appid="$applicationId">',
          color: TerminalColor.yellow,
        );
        _warningShown = true;
      }
      if (tag != 'ui-application' && tag != 'service-application') {
        globals.printStatus(
          'Warning: tizen-manifest.xml: <$tag> is not officially supported.',
          color: TerminalColor.yellow,
        );
        _warningShown = true;
      }
    }
    return applicationId;
  }

  /// To prevent spamming log with warnings, remember they have been shown.
  static bool _warningShown = false;

  @override
  String toString() => _document.toXmlString(pretty: true, indent: '    ');
}

/// Represents the content of `signature1.xml` or `author-signature.xml` file.
class Signature {
  const Signature(this._document);

  static Signature parseFromXml(File xmlFile) {
    if (xmlFile == null || !xmlFile.existsSync()) {
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
    return Signature(document);
  }

  final XmlDocument _document;

  String get signatureValue {
    final XmlElement signature = _document.rootElement;
    for (final XmlElement elem in signature.findElements('SignatureValue')) {
      return elem.text.replaceAll(RegExp(r'\s+'), '');
    }
    return null;
  }
}

class SecurityProfiles {
  SecurityProfiles._(this.profiles, {@required this.active});

  static SecurityProfiles parseFromXml(File xmlFile) {
    if (xmlFile == null || !xmlFile.existsSync()) {
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

    String active = document.rootElement.getAttribute('active');
    if (active != null && active.isEmpty) {
      active = null;
    }

    final List<String> profiles = <String>[];
    for (final XmlElement profile
        in document.rootElement.findAllElements('profile')) {
      final String name = profile.getAttribute('name');
      if (name != null) {
        profiles.add(name);
      }
    }

    return SecurityProfiles._(profiles, active: active);
  }

  final List<String> profiles;
  final String active;

  bool contains(String name) => profiles.contains(name);
}
