// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import 'tizen_project.dart';

/// [ApplicationPackageFactory] extended for Tizen.
class TpkFactory extends ApplicationPackageFactory {
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

/// [ApplicationPackageStore] extended for Tizen.
class TpkStore extends ApplicationPackageStore {
  @override
  Future<ApplicationPackage> getPackageForPlatform(
    TargetPlatform platform,
    BuildInfo buildInfo,
  ) async {
    if (platform == TargetPlatform.tester) {
      return await TizenTpk.fromProject(FlutterProject.current());
    }
    return super.getPackageForPlatform(platform, buildInfo);
  }
}

/// See: [AndroidApk] in `application_package.dart`
class TizenTpk extends ApplicationPackage {
  TizenTpk({
    @required this.file,
    @required this.manifest,
    this.signature,
  })  : assert(file != null),
        super(id: manifest.packageId);

  static Future<TizenTpk> fromTpk(File tpk) async {
    final Directory tempDir = globals.fs.systemTempDirectory.createTempSync();
    globals.os.unzip(tpk, tempDir);

    // We have to manually restore permissions for files zipped by
    // build-task-tizen on Unix.
    // Issue: https://github.com/dotnet/runtime/issues/1548
    await tempDir.list(recursive: true).forEach((FileSystemEntity entity) {
      if (entity is File) {
        globals.os.chmod(entity, '644');
      }
    });

    final File manifestFile = tempDir.childFile('tizen-manifest.xml');
    if (!manifestFile.existsSync()) {
      throwToolExit('tizen-manifest.xml could not be found.');
    }
    final File signatureFile = tempDir.childFile('author-signature.xml');

    return TizenTpk(
      file: tpk,
      manifest: TizenManifest.parseFromXml(manifestFile),
      signature: Signature.parseFromXml(signatureFile),
    );
  }

  static Future<TizenTpk> fromProject(FlutterProject flutterProject) async {
    final TizenProject project = TizenProject.fromFlutter(flutterProject);
    if (!project.manifestFile.existsSync()) {
      throwToolExit('tizen-manifest.xml could not be found.');
    }

    final File tpkFile = flutterProject.directory
        .childDirectory('build')
        .childDirectory('tizen')
        .childFile(project.outputTpkName);
    if (tpkFile.existsSync()) {
      return await TizenTpk.fromTpk(tpkFile);
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
  String get applicationId => manifest?.applicationId;

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

  factory TizenManifest.parseFromXml(File xmlFile) {
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
      throwToolExit('Failed to parse ${xmlFile.basename}: $ex');
    }
    return TizenManifest(document);
  }

  final XmlDocument _document;

  XmlElement get _manifest => _document.rootElement;

  /// The package name.
  String get packageId => _manifest.getAttribute('package');

  /// The package version number in the "x.y.z" format.
  String get version => _manifest.getAttribute('version');
  set version(String version) => _manifest.setAttribute('version', version);

  /// The target API version number.
  String get apiVersion => _manifest.getAttribute('api-version');

  /// The profile name representing a device type.
  String get profileName =>
      _manifest.findElements('profile').first.getAttribute('name');

  /// The fully qualified profile string. (e.g. `wearable-5.5`)
  String get profile => '$profileName-$apiVersion';

  /// The unique application id used for launching and terminating applications.
  String get applicationId {
    final XmlElement parent = _manifest.findElements('ui-application').first;
    return parent.getAttribute('appid');
  }

  @override
  String toString() => _document.toXmlString(pretty: true, indent: '    ');
}

/// Represents the content of `signature1.xml` or `author-signature.xml` file.
class Signature {
  const Signature(this._document);

  factory Signature.parseFromXml(File xmlFile) {
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
      globals.printStatus(
        'Warning: Failed to parse ${xmlFile.basename}: $ex',
        color: TerminalColor.yellow,
      );
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

class Certificate {
  Certificate._({
    @required this.key,
    @required this.password,
    @required this.distributorNumber,
    @required this.ca,
  });

  factory Certificate.parseFromXmlElement(XmlElement profileItem) {
    final String ca = profileItem.getAttribute('ca');
    final String key = profileItem.getAttribute('key');
    final String password = profileItem.getAttribute('password');
    final String distributorNumber = profileItem.getAttribute('distributor');

    // The certificate doesn't exist and the profileitem
    // exists only as a placeholder
    if (key.isEmpty || password.isEmpty) {
      return null;
    }

    return Certificate._(
      key: key,
      password: password,
      distributorNumber: distributorNumber,
      ca: ca,
    );
  }

  final String key;
  final String password;
  final String distributorNumber;
  final String ca;

  bool get isSamsungCertificate => ca.isEmpty;
  bool get isTizenCertificate => ca.isNotEmpty;
}

class CertificateProfile {
  CertificateProfile(
    this.name, {
    @required this.authorCertificate,
    @required this.distributorCertificates,
  });

  factory CertificateProfile.parseFromXmlElement(XmlElement profile) {
    Certificate authorCertificate;
    final List<Certificate> distributorCertificates = <Certificate>[];

    final String name = profile.getAttribute('name');

    // The element that holds a single certifcate key, password pair
    for (final XmlElement profileItem
        in profile.findAllElements('profileitem')) {
      final Certificate tizenCertificate =
          Certificate.parseFromXmlElement(profileItem);
      if (tizenCertificate != null) {
        // distributor number 0 specifies an author certificate
        tizenCertificate.distributorNumber == '0'
            ? authorCertificate = tizenCertificate
            : distributorCertificates.add(tizenCertificate);
      }
    }

    return CertificateProfile(
      name,
      authorCertificate: authorCertificate,
      distributorCertificates: distributorCertificates,
    );
  }

  final String name;
  final Certificate authorCertificate;
  final List<Certificate> distributorCertificates;

  bool get isSamsungProfile =>
      authorCertificate.isSamsungCertificate &&
      distributorCertificates
          .every((Certificate certificate) => certificate.isSamsungCertificate);

  bool get isTizenProfile =>
      authorCertificate.isTizenCertificate &&
      distributorCertificates
          .every((Certificate certificate) => certificate.isTizenCertificate);

  bool get isMixedProfile => !isSamsungProfile && !isTizenProfile;
}

class CertificateProfiles {
  CertificateProfiles._(this._document, this.profiles);

  factory CertificateProfiles.parseFromXml(File xmlFile) {
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
      throwToolExit('Failed to parse ${xmlFile.basename}: $ex');
    }

    final List<CertificateProfile> tizenCertificateProfiles =
        <CertificateProfile>[
      ...document.rootElement.findAllElements('profile').map(
          (XmlElement profile) =>
              CertificateProfile.parseFromXmlElement(profile))
    ];

    return CertificateProfiles._(document, tizenCertificateProfiles);
  }

  final XmlDocument _document;
  final List<CertificateProfile> profiles;

  XmlElement get _root => _document.rootElement;

  String get activeProfileName => _root.getAttribute('active').isNotEmpty
      ? _root.getAttribute('active')
      : null;

  CertificateProfile get activeProfile => getProfileByName(activeProfileName);

  CertificateProfile getProfileByName(String name) {
    return profiles.firstWhere(
      (CertificateProfile certificateProfile) =>
          certificateProfile.name == name,
      orElse: () => null,
    );
  }

  bool existsProfile(String name) => getProfileByName(name) != null;

  @override
  String toString() => _document.toXmlString(pretty: true, indent: '    ');
}
