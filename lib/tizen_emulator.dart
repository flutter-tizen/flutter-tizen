// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/emulator.dart';
import 'package:flutter_tools/src/base/logger.dart';
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

  /// Create Tizen emulators
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
          success: false,
          error: 'emulator manager is missing from the Tizen Studio');
    }

    final PlatformImage platformImage = await _getPreferredPlatformImage();
    if (platformImage == null) {
      return CreateEmulatorResult(name,
          success: false,
          error:
              'No suitable Tizen platform images are available. You may need to install these'
              ' using the package manager.');
    }
    final RunResult runResult = await _processUtils.run(<String>[
      getEmCliPath(),
      'create',
      '-n',
      name,
      '-p',
      platformImage.name,
      '-t',
      preferredDevices[platformImage.profile],
    ]);
    return CreateEmulatorResult(name,
        success: runResult.exitCode == 0, output: runResult.stdout);
  }

  static const Map<String, String> preferredDevices = <String, String>{
    'tv': 'HD1080 TV',
    'wearable': 'Wearable Circle',
  };

  static const Map<String, int> profilePriority = <String, int>{
    'tv': 1,
    'wearable': 2,
  };

  Future<List<PlatformImage>> _loadAllPlatformImages() async {
    final Directory platforms = _tizenSdk.directory.childDirectory('platforms');
    if (!await platforms.exists()) {
      return <PlatformImage>[];
    }

    final List<PlatformImage> platformImages = <PlatformImage>[];
    await for (final FileSystemEntity entity in platforms.list()) {
      if (entity is Directory) {
        platformImages.addAll(await _loadPlatformImagesPerVersion(entity));
      }
    }
    return platformImages;
  }

  Future<List<PlatformImage>> _loadPlatformImagesPerVersion(
      Directory platformDirectory) async {
    final List<PlatformImage> platformImages = <PlatformImage>[];
    await for (final FileSystemEntity entity in platformDirectory.list()) {
      if (entity is Directory) {
        platformImages.addAll(await _loadPlatformImagesPerProfile(entity));
      }
    }
    return platformImages;
  }

  Future<List<PlatformImage>> _loadPlatformImagesPerProfile(
      Directory profileDirectory) async {
    final Directory emulatorImages =
        profileDirectory.childDirectory('emulator-images');
    if (!await emulatorImages.exists()) {
      return <PlatformImage>[];
    }

    final List<PlatformImage> platformImages = <PlatformImage>[];
    await for (final FileSystemEntity entity in emulatorImages.list()) {
      if (entity is Directory && entity.basename != 'add-ons') {
        final File infoFile = entity.childFile('info.ini');
        if (await infoFile.exists()) {
          final Map<String, String> info =
              parseIniLines(await infoFile.readAsLines());
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

  Future<PlatformImage> _getPreferredPlatformImage() async {
    final List<PlatformImage> platformImages = await _loadAllPlatformImages();
    
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
    return super.canListAnything || _tizenEmulators.canListAnything;
  }
}

class PlatformImage {
  PlatformImage(
      {@required this.name, @required this.profile, @required this.version});

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
  // TODO(HakkyuKim): fix the code so that it actually evaluates the bool value
  bool get canLaunchAnything => true;
  @override
  // TODO(HakkyuKim): fix the code so that it actually evaluates the bool value
  bool get canListAnything => true;

  @override
  Future<List<Emulator>> get emulators => _getEmulators();

  Future<Directory> _getTizenSdkDataDirectory() async {
    final File sdkInfo = _tizenSdk.directory.childFile('sdk.info');
    if (await sdkInfo.exists()) {
      final List<String> lines = await sdkInfo.readAsLines();
      for (final String line in lines) {
        final List<String> tokens = line.split('=');
        if (tokens[0].trim() == 'TIZEN_SDK_DATA_PATH') {
          return _fileSystem.directory(tokens[1].trim());
        }
      }
    }
    return null;
  }

  Future<List<Emulator>> _getEmulators() async {
    final Directory tizenSdkDataDirectory = await _getTizenSdkDataDirectory();
    if (tizenSdkDataDirectory == null) {
      return <Emulator>[];
    }
    _emulatorDirectory =
        tizenSdkDataDirectory.childDirectory('emulator').childDirectory('vms');

    final List<Emulator> emulators = <Emulator>[];
    if (await _emulatorDirectory.exists()) {
      await for (final FileSystemEntity entity in _emulatorDirectory.list()) {
        if (entity is Directory &&
            await entity.childFile('vm_config.xml').exists()) {
          final String id = entity.basename;
          emulators.add(await _loadEmulatorInfo(id));
        }
      }
    }
    return emulators;
  }

  Future<TizenEmulator> _loadEmulatorInfo(String id) async {
    id = id.trim();
    final File configFile =
        _emulatorDirectory.childDirectory(id).childFile('vm_config.xml');
    final Map<String, String> properties = <String, String>{};

    final XmlDocument xmlDocument =
        XmlDocument.parse(await configFile.readAsString());
    final String name = xmlDocument.findAllElements('name').first.text;
    final XmlElement diskImage = xmlDocument.findAllElements('diskImage').first;
    final String profile = diskImage.getAttribute('profile');
    final String version = diskImage.getAttribute('version');
    properties['name'] = name;
    properties['profile'] = profile;
    properties['version'] = version;

    return TizenEmulator(id,
        properties: properties,
        logger: _logger,
        processManager: _processManager);
  }

  @override
  // TODO(HakkyuKim): fix the code so that it actually evaluates the bool value
  bool get supportsPlatform => true;
}

class TizenEmulator extends Emulator {
  TizenEmulator(String id,
      {Map<String, String> properties,
      @required Logger logger,
      @required ProcessManager processManager})
      : _properties = properties,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        super(id, properties != null && properties.isNotEmpty);

  final Map<String, String> _properties;
  final ProcessUtils _processUtils;

  String _prop(String name) => _properties != null ? _properties[name] : null;

  // Should we subcategorize it based on Tizen profile?
  @override
  Category get category => Category.mobile;

  @override
  Future<void> launch() async {
    // TODO(HakkyuKim): launch is overly simplified, for example, it currently doesn't record the emulator process.
    /// See [AndroidEmulator.launch()] in [android_emulator.dart]
    final List<String> args = <String>[getEmCliPath(), 'launch', '--name', id];
    await _processUtils.run(args);
    return;
  }

  @override
  String get manufacturer => 'Samsung';

  @override
  String get name => id;

  // This should be changed to Tizen later
  @override
  PlatformType get platformType => PlatformType.linux;

  String get profile => _prop('profile');

  String get version => _prop('version');
}

Map<String, String> parseIniLines(List<String> contents) {
  final Map<String, String> results = <String, String>{};

  final Iterable<List<String>> properties = contents
      .map<String>((String l) => l.trim())
      // Strip blank lines/comments
      .where((String l) => l != '' && !l.startsWith('#'))
      // Discard anything that isn't simple name=value
      .where((String l) => l.contains('='))
      // Split into name/value
      .map<List<String>>((String l) => l.split('='));

  for (final List<String> property in properties) {
    results[property[0].trim()] = property[1].trim();
  }

  return results;
}
