// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/emulator.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';
import 'package:xml/xml.dart';

class TizenEmulatorManager extends EmulatorManager {
  TizenEmulatorManager({
    @required AndroidSdk androidSdk,
    @required AndroidWorkflow androidWorkflow,
    @required FileSystem fileSystem,
    @required Logger logger,
    @required ProcessManager processManager,
    @required TizenSdk tizenSdk,
  })  : _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        _tizenSdk = tizenSdk,
        _tizenEmulators = TizenEmulators(
          fileSystem: fileSystem,
          logger: logger,
          processManager: processManager,
          tizenSdk: tizenSdk,
        ),
        super(
          androidSdk: androidSdk,
          androidWorkflow: androidWorkflow,
          fileSystem: fileSystem,
          logger: logger,
          processManager: processManager,
        );

  final ProcessUtils _processUtils;
  final TizenSdk _tizenSdk;
  final TizenEmulators _tizenEmulators;

  /// Creates Tizen emulators
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
            'You may need to install these using the Tizen Package Manager.',
      );
    }

    final RunResult runResult = await _processUtils.run(
      <String>[
        _tizenSdk.emCli.path,
        'create',
        '-n',
        name,
        '-p',
        platformImage.name,
        '-t',
        preferredDevices[platformImage.profile],
      ],
    );

    return CreateEmulatorResult(
      name,
      success: runResult.exitCode == 0,
      output: runResult.stdout,
    );
  }

  static const Map<String, String> preferredDevices = <String, String>{
    'tv': 'HD1080 TV',
    'wearable': 'Wearable Circle',
  };

  static const Map<String, int> profilePriority = <String, int>{
    'tv': 1,
    'wearable': 2,
  };

  List<PlatformImage> _loadAllPlatformImages() {
    final Directory platforms = _tizenSdk.directory.childDirectory('platforms');
    if (!platforms.existsSync()) {
      return <PlatformImage>[];
    }

    final List<PlatformImage> platformImages = <PlatformImage>[];
    for (final FileSystemEntity entity in platforms.listSync()) {
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
    final Directory emulatorImages =
        profileDirectory.childDirectory('emulator-images');
    if (!emulatorImages.existsSync()) {
      return <PlatformImage>[];
    }

    final List<PlatformImage> platformImages = <PlatformImage>[];
    for (final FileSystemEntity entity in emulatorImages.listSync()) {
      if (entity is Directory && entity.basename != 'add-ons') {
        final File infoFile = entity.childFile('info.ini');
        if (infoFile.existsSync()) {
          final Map<String, String> info =
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
    }
    return platformImages;
  }

  PlatformImage _getPreferredPlatformImage() {
    final List<PlatformImage> platformImages = _loadAllPlatformImages();

    // Selects an image with the highest platform version among available profiles.
    // TV profiles have priority over wearable profiles.
    platformImages?.sort((PlatformImage a, PlatformImage b) {
      if (a.profile == b.profile) {
        return -a.version.compareTo(b.version);
      }
      return profilePriority[a.profile].compareTo(profilePriority[b.profile]);
    });
    return platformImages?.first;
  }

  @override
  Future<List<Emulator>> getAllAvailableEmulators() async {
    final List<Emulator> emulators = await _tizenEmulators.emulators;
    emulators.addAll(await super.getAllAvailableEmulators());
    return emulators;
  }

  @override
  bool get canListAnything {
    return _tizenEmulators.canListAnything;
  }
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

class TizenEmulators extends EmulatorDiscovery {
  TizenEmulators({
    @required FileSystem fileSystem,
    @required Logger logger,
    @required ProcessManager processManager,
    @required TizenSdk tizenSdk,
  })  : _fileSystem = fileSystem,
        _logger = logger,
        _processManager = processManager,
        _tizenSdk = tizenSdk;

  final FileSystem _fileSystem;
  final Logger _logger;
  final ProcessManager _processManager;
  final TizenSdk _tizenSdk;

  Directory _emulatorDirectory;

  @override
  bool get canLaunchAnything => _tizenSdk?.emCli?.existsSync() ?? false;

  @override
  bool get canListAnything => _tizenSdk?.emCli?.existsSync() ?? false;

  @override
  Future<List<Emulator>> get emulators async {
    if (!canListAnything) {
      // Although this method doesn't run the `tizenSdk.emCli` command
      // to get emulator info, logically, emulator info shouldn't be
      // available without the Tizen Emulator Manager(tizenSdk.emCli).
      return <Emulator>[];
    }

    final Directory tizenSdkDataDirectory = _tizenSdk.sdkDataDirectory;
    if (tizenSdkDataDirectory == null) {
      return <Emulator>[];
    }
    _emulatorDirectory =
        tizenSdkDataDirectory.childDirectory('emulator').childDirectory('vms');

    final List<Emulator> emulators = <Emulator>[];
    if (_emulatorDirectory.existsSync()) {
      for (final FileSystemEntity entity in _emulatorDirectory.listSync()) {
        if (entity is Directory &&
            entity.childFile('vm_config.xml').existsSync()) {
          final String id = entity.basename;
          emulators.add(_loadEmulatorInfo(id));
        }
      }
    }
    return emulators;
  }

  TizenEmulator _loadEmulatorInfo(String id) {
    id = id.trim();
    final File configFile =
        _emulatorDirectory.childDirectory(id).childFile('vm_config.xml');
    final Map<String, String> properties = <String, String>{};

    final XmlDocument xmlDocument =
        XmlDocument.parse(configFile.readAsStringSync());
    final String name = xmlDocument.findAllElements('name').first.text;
    final XmlElement diskImage = xmlDocument.findAllElements('diskImage').first;
    final String profile = diskImage.getAttribute('profile');
    final String version = diskImage.getAttribute('version');
    properties['name'] = name;
    properties['profile'] = profile;
    properties['version'] = version;

    return TizenEmulator(
      id,
      properties: properties,
      logger: _logger,
      processManager: _processManager,
      tizenSdk: _tizenSdk,
    );
  }

  /// Tizen emulator supports all major platforms(Windows/macOS/Linux).
  @override
  bool get supportsPlatform => true;
}

class TizenEmulator extends Emulator {
  TizenEmulator(
    String id, {
    Map<String, String> properties,
    @required Logger logger,
    @required ProcessManager processManager,
    @required TizenSdk tizenSdk,
  })  : _logger = logger,
        _properties = properties,
        _processUtils = ProcessUtils(
          logger: logger,
          processManager: processManager,
        ),
        _tizenSdk = tizenSdk,
        super(
          id,
          properties != null && properties.isNotEmpty,
        );

  final Logger _logger;
  final Map<String, String> _properties;
  final ProcessUtils _processUtils;
  final TizenSdk _tizenSdk;

  String _prop(String name) => _properties != null ? _properties[name] : null;

  // TODO(HakkyuKim): Consider subcategorizing into Tizen profiles.
  @override
  Category get category => Category.mobile;

  /// See [AndroidEmulator.launch] in [android_emulator.dart] (simplified)
  @override
  Future<void> launch() async {
    final String emCliPath = _tizenSdk?.emCli?.path;
    if (emCliPath == null) {
      throwToolExit('Unable to locate Tizen Emulator Manager.');
    }

    final List<String> args = <String>[
      emCliPath,
      'launch',
      '--name',
      id,
    ];

    final RunResult runResult = await _processUtils.run(args);
    if (runResult.exitCode == 0) {
      globals.printStatus('Successfully launched Tizen emulator, $id.');
    } else if (runResult.exitCode == 2) {
      globals.printStatus('Tizen emulator $id is already running.');
    } else {
      throwToolExit('Unable to launch Tizen emulator $id.');
    }
    return;
  }

  @override
  String get manufacturer => 'Samsung';

  @override
  String get name => id;

  // TODO(HakkyuKim): Consider replacing it to Tizen.
  @override
  PlatformType get platformType => PlatformType.linux;

  String get profile => _prop('profile');

  String get version => _prop('version');
}
