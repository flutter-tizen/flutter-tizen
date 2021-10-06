// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_emulator.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/emulator.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';
import 'package:xml/xml.dart';

import 'tizen_doctor.dart';
import 'tizen_sdk.dart';

/// A class to get available Tizen emulators.
class TizenEmulatorManager extends EmulatorManager {
  TizenEmulatorManager({
    @required TizenSdk tizenSdk,
    @required TizenWorkflow tizenWorkflow,
    @required FileSystem fileSystem,
    @required Logger logger,
    @required ProcessManager processManager,
  })  : _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        _tizenSdk = tizenSdk,
        _tizenEmulators = TizenEmulators(
          logger: logger,
          processManager: processManager,
          tizenSdk: tizenSdk,
          tizenWorkflow: tizenWorkflow,
        ),
        super(
          androidSdk: null,
          androidWorkflow: null,
          fileSystem: fileSystem,
          logger: logger,
          processManager: processManager,
        );

  final ProcessUtils _processUtils;
  final TizenSdk _tizenSdk;
  final TizenEmulators _tizenEmulators;

  /// Creates a Tizen emulator.
  ///
  /// Source: [EmulatorManager.createEmulator] in `emulator.dart`
  @override
  Future<CreateEmulatorResult> createEmulator({String name}) async {
    if (name == null || name.isEmpty) {
      const String autoName = 'flutter_emulator';
      final List<Emulator> all = await getAllAvailableEmulators();
      final Set<String> takenNames = all
          .map<String>((Emulator e) => e.id)
          .where((String id) => id.startsWith(autoName))
          .toSet();
      int suffix = 1;
      name = autoName;
      while (takenNames.contains(name)) {
        name = '${autoName}_${++suffix}';
      }
    }
    if (!_tizenEmulators.canLaunchAnything) {
      return CreateEmulatorResult(name,
          success: false, error: 'Unable to locate Tizen Emulator Manager.');
    }

    final PlatformImage platformImage = _getPreferredPlatformImage();
    if (platformImage == null) {
      return CreateEmulatorResult(
        name,
        success: false,
        error: 'No suitable Tizen platform images are available.\n'
            'You may need to install these using Tizen Package Manager.',
      );
    }

    assert(_tizenSdk != null);
    final RunResult runResult = await _processUtils.run(
      <String>[
        _tizenSdk.emCli.path,
        'create',
        '-n',
        name,
        '-p',
        platformImage.name,
      ],
    );
    return CreateEmulatorResult(
      name,
      success: runResult.exitCode == 0,
      output: runResult.stdout,
      error: runResult.stderr,
    );
  }

  List<PlatformImage> _loadAllPlatformImages() {
    assert(_tizenSdk != null);
    final Directory platformsDir = _tizenSdk.platformsDirectory;
    if (!platformsDir.existsSync()) {
      return <PlatformImage>[];
    }

    final List<PlatformImage> platformImages = <PlatformImage>[];
    for (final FileSystemEntity entity in platformsDir.listSync()) {
      if (entity is Directory) {
        platformImages.addAll(_loadPlatformImagesPerVersion(entity));
      }
    }
    return platformImages;
  }

  List<PlatformImage> _loadPlatformImagesPerVersion(
      Directory platformDirectory) {
    final List<PlatformImage> platformImages = <PlatformImage>[];
    for (final FileSystemEntity entity in platformDirectory.listSync()) {
      if (entity is Directory) {
        platformImages.addAll(_loadPlatformImagesPerProfile(entity));
      }
    }
    return platformImages;
  }

  List<PlatformImage> _loadPlatformImagesPerProfile(
      Directory profileDirectory) {
    final Directory emulatorImagesDir =
        profileDirectory.childDirectory('emulator-images');
    if (!emulatorImagesDir.existsSync()) {
      return <PlatformImage>[];
    }

    final List<PlatformImage> platformImages = <PlatformImage>[];
    for (final FileSystemEntity entity in emulatorImagesDir.listSync()) {
      if (entity is Directory && entity.basename != 'add-ons') {
        final File infoFile = entity.childFile('info.ini');
        if (!infoFile.existsSync()) {
          continue;
        }
        final Map<String, String> info =
            // ignore: invalid_use_of_visible_for_testing_member
            parseIniLines(infoFile.readAsLinesSync());
        if (info.containsKey('name') &&
            info.containsKey('profile') &&
            info.containsKey('version')) {
          platformImages.add(PlatformImage(
            name: info['name'],
            profile: info['profile'],
            version: info['version'],
          ));
        }
      }
    }
    return platformImages;
  }

  PlatformImage _getPreferredPlatformImage() {
    final List<PlatformImage> platformImages = _loadAllPlatformImages();
    if (platformImages.isEmpty) {
      return null;
    }
    // Selects an image with the highest platform version among available profiles.
    // TV profile takes priority over other profiles.
    platformImages.sort((PlatformImage a, PlatformImage b) {
      return -a.version.compareTo(b.version);
    });
    return platformImages.firstWhere(
      (PlatformImage image) => image.profile == 'tv',
      orElse: () => platformImages.first,
    );
  }

  @override
  Future<List<Emulator>> getAllAvailableEmulators() =>
      _tizenEmulators.emulators;

  @override
  bool get canListAnything => _tizenEmulators.canListAnything;
}

class PlatformImage {
  PlatformImage({
    @required this.name,
    @required this.profile,
    @required this.version,
  });

  final String name;
  final String profile;
  final String version;

  @override
  String toString() => '$name $profile $version';
}

/// See: [AndroidEmulators] in `android_emulator.dart`
class TizenEmulators extends EmulatorDiscovery {
  TizenEmulators({
    @required TizenSdk tizenSdk,
    @required TizenWorkflow tizenWorkflow,
    @required Logger logger,
    @required ProcessManager processManager,
  })  : _tizenSdk = tizenSdk,
        _tizenWorkflow = tizenWorkflow,
        _logger = logger,
        _processManager = processManager;

  final TizenSdk _tizenSdk;
  final TizenWorkflow _tizenWorkflow;
  final Logger _logger;
  final ProcessManager _processManager;

  @override
  bool get canListAnything => _tizenWorkflow.canListEmulators;

  @override
  bool get canLaunchAnything => _tizenWorkflow.canListEmulators;

  /// Tizen emulator supports all major platforms (Windows/macOS/Linux).
  @override
  bool get supportsPlatform => true;

  @override
  Future<List<Emulator>> get emulators async {
    if (!canListAnything) {
      return <Emulator>[];
    }

    assert(_tizenSdk != null);
    final Directory emulatorDir = _tizenSdk.sdkDataDirectory
        .childDirectory('emulator')
        .childDirectory('vms');
    if (!emulatorDir.existsSync()) {
      return <Emulator>[];
    }

    TizenEmulator loadEmulatorInfo(Directory directory) {
      final String id = directory.basename;
      final File configFile =
          emulatorDir.childDirectory(id).childFile('vm_config.xml');
      if (!configFile.existsSync()) {
        return null;
      }

      XmlDocument document;
      try {
        document = XmlDocument.parse(configFile.readAsStringSync().trim());
      } on XmlException {
        return null;
      }

      final Map<String, String> properties = <String, String>{};
      final Iterable<XmlElement> deviceTemplates =
          document.findAllElements('deviceTemplate');
      final Iterable<XmlElement> diskImages =
          document.findAllElements('diskImage');
      if (deviceTemplates.isNotEmpty && diskImages.isNotEmpty) {
        properties['name'] = deviceTemplates.first.getAttribute('name');
        properties['profile'] = diskImages.first.getAttribute('profile');
        properties['version'] = diskImages.first.getAttribute('version');
      }

      return TizenEmulator(
        id,
        properties: properties,
        logger: _logger,
        processManager: _processManager,
        tizenSdk: _tizenSdk,
      );
    }

    final List<Emulator> emulators = <Emulator>[];
    for (final Directory dir in emulatorDir.listSync().whereType<Directory>()) {
      final TizenEmulator emulator = loadEmulatorInfo(dir);
      if (emulator != null) {
        emulators.add(emulator);
      }
    }
    return emulators;
  }
}

/// See: [AndroidEmulator] in `android_emulator.dart`
class TizenEmulator extends Emulator {
  TizenEmulator(
    String id, {
    Map<String, String> properties,
    @required Logger logger,
    @required ProcessManager processManager,
    @required TizenSdk tizenSdk,
  })  : assert(tizenSdk != null),
        _properties = properties,
        _logger = logger,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        _tizenSdk = tizenSdk,
        super(id, properties != null && properties.isNotEmpty);

  final Map<String, String> _properties;
  final Logger _logger;
  final ProcessUtils _processUtils;
  final TizenSdk _tizenSdk;

  String _prop(String name) => _properties != null ? _properties[name] : null;

  @override
  String get name => _prop('name') ?? id;

  @override
  String get manufacturer => 'Samsung';

  @override
  Category get category => Category.mobile;

  @override
  PlatformType get platformType => PlatformType.custom;

  @override
  Future<void> launch({bool coldBoot}) async {
    final File emCli = _tizenSdk.emCli;
    if (emCli == null || !emCli.existsSync()) {
      throwToolExit('Unable to locate Tizen Emulator Manager.');
    }

    final RunResult result =
        await _processUtils.run(<String>[emCli.path, 'launch', '--name', id]);
    if (result.exitCode == 0) {
      _logger.printStatus('Successfully launched Tizen emulator $id.');
    } else if (result.stdout.contains('is running now...')) {
      _logger.printStatus('Tizen emulator $id is already running.');
    } else {
      _logger.printError(result.stdout);
      _logger.printError('Could not launch Tizen emulator $id.');
    }
  }
}
