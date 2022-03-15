// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_emulator.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/emulator.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'tizen_doctor.dart';
import 'tizen_sdk.dart';

/// A class to get available Tizen emulators.
class TizenEmulatorManager extends EmulatorManager {
  TizenEmulatorManager({
    required TizenSdk? tizenSdk,
    required TizenWorkflow tizenWorkflow,
    required FileSystem fileSystem,
    required Logger logger,
    required ProcessManager processManager,
    AndroidWorkflow? dummyAndroidWorkflow,
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
          androidWorkflow: dummyAndroidWorkflow ?? androidWorkflow!,
          fileSystem: fileSystem,
          logger: logger,
          processManager: processManager,
        );

  final ProcessUtils _processUtils;
  final TizenSdk? _tizenSdk;
  final TizenEmulators _tizenEmulators;

  /// Creates a Tizen emulator.
  ///
  /// Source: [EmulatorManager.createEmulator] in `emulator.dart`
  @override
  Future<CreateEmulatorResult> createEmulator({String? name}) async {
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
    final String emulatorName = name!;
    if (!_tizenEmulators.canLaunchAnything) {
      return CreateEmulatorResult(emulatorName,
          success: false, error: 'Unable to locate Tizen Emulator Manager.');
    }

    final PlatformImage? platformImage = _getPreferredPlatformImage();
    if (platformImage == null) {
      return CreateEmulatorResult(
        emulatorName,
        success: false,
        error: 'No suitable Tizen platform images are available.\n'
            'You may need to install these using Tizen Package Manager.',
      );
    }
    final RunResult runResult = await _processUtils.run(
      <String>[
        _tizenSdk!.emCli.path,
        'create',
        '-n',
        emulatorName,
        '-p',
        platformImage.name,
      ],
    );
    return CreateEmulatorResult(
      emulatorName,
      success: runResult.exitCode == 0,
      output: runResult.stdout,
      error: runResult.stderr,
    );
  }

  PlatformImage? _getPreferredPlatformImage() {
    final RunResult result = _processUtils.runSync(
      <String>[_tizenSdk!.emCli.path, 'list-platform', '-d'],
      throwOnError: true,
    );
    final Map<String, Map<String, String>> parsed =
        parseEmCliOutput(result.stdout);

    final List<PlatformImage> platformImages = <PlatformImage>[];
    parsed.forEach((String name, Map<String, String> properties) {
      if (properties.containsKey('Profile') &&
          properties.containsKey('Version')) {
        platformImages.add(PlatformImage(
          name: name,
          profile: properties['Profile']!,
          version: properties['Version']!,
        ));
      }
    });
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
    required this.name,
    required this.profile,
    required this.version,
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
    required TizenSdk? tizenSdk,
    required TizenWorkflow tizenWorkflow,
    required Logger logger,
    required ProcessManager processManager,
  })  : _tizenSdk = tizenSdk,
        _tizenWorkflow = tizenWorkflow,
        _logger = logger,
        _processManager = processManager,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager);

  final TizenSdk? _tizenSdk;
  final TizenWorkflow _tizenWorkflow;
  final Logger _logger;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;

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

    final RunResult result = _processUtils.runSync(
      <String>[_tizenSdk!.emCli.path, 'list-vm', '-d'],
      throwOnError: true,
    );
    final Map<String, Map<String, String>> parsed =
        parseEmCliOutput(result.stdout);

    final List<Emulator> emulators = <Emulator>[];
    parsed.forEach((String id, Map<String, String> properties) {
      emulators.add(TizenEmulator(
        id,
        properties: properties,
        logger: _logger,
        processManager: _processManager,
        tizenSdk: _tizenSdk,
      ));
    });
    return emulators;
  }
}

/// See: [AndroidEmulator] in `android_emulator.dart`
class TizenEmulator extends Emulator {
  TizenEmulator(
    String id, {
    Map<String, String> properties = const <String, String>{},
    required Logger logger,
    required ProcessManager processManager,
    required TizenSdk? tizenSdk,
  })  : _properties = properties,
        _logger = logger,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        _tizenSdk = tizenSdk,
        super(id, properties.isNotEmpty);

  final Map<String, String> _properties;
  final Logger _logger;
  final ProcessUtils _processUtils;
  final TizenSdk? _tizenSdk;

  @override
  String get name => _properties['Template'] ?? id;

  @override
  String? get manufacturer => 'Samsung';

  @override
  Category get category => Category.mobile;

  @override
  PlatformType get platformType => PlatformType.custom;

  @override
  Future<void> launch({bool coldBoot = false}) async {
    final File? emCli = _tizenSdk?.emCli;
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

@visibleForTesting
Map<String, Map<String, String>> parseEmCliOutput(String lines) {
  final Map<String, Map<String, String>> result =
      <String, Map<String, String>>{};
  String? lastId;
  for (final String line in LineSplitter.split(lines)) {
    if (line.trim().isEmpty) {
      continue;
    } else if (!line.startsWith('  ')) {
      lastId = line.trim();
      result[lastId] = <String, String>{};
    } else if (lastId != null && line.contains(':')) {
      final String key = line.split(':')[0].trim();
      final String value = line.split(':')[1].trim();
      result[lastId]![key] = value;
    }
  }
  return result;
}
