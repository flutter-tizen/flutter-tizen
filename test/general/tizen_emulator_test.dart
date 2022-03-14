// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_doctor.dart';
import 'package:flutter_tizen/tizen_emulator.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/emulator.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_tizen_sdk.dart';
import '../src/fakes.dart';

void main() {
  FileSystem fileSystem;
  FakeProcessManager processManager;
  FakeTizenSdk tizenSdk;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();
    tizenSdk = FakeTizenSdk(fileSystem);
  });

  group('TizenEmulatorManager', () {
    TizenEmulatorManager manager;

    setUp(() {
      manager = TizenEmulatorManager(
        tizenSdk: tizenSdk,
        tizenWorkflow: TizenWorkflow(
          tizenSdk: tizenSdk,
          operatingSystemUtils: FakeOperatingSystemUtils(),
        ),
        fileSystem: fileSystem,
        logger: BufferLogger.test(),
        processManager: processManager,
        dummyAndroidWorkflow: AndroidWorkflow(
          androidSdk: null,
          featureFlags: TestFeatureFlags(),
          operatingSystemUtils: FakeOperatingSystemUtils(),
        ),
      );
    });

    testWithoutContext('Cannot create emulator if no image found', () async {
      final CreateEmulatorResult result = await manager.createEmulator();
      expect(result.success, isFalse);
      expect(result.error,
          contains('No suitable Tizen platform images are available.'));
    });

    testWithoutContext('Can create emulator without name', () async {
      final File imageInfo = tizenSdk.platformsDirectory
          .childFile('tizen-1.0/common/emulator-images/image_name/info.ini');
      imageInfo
        ..createSync(recursive: true)
        ..writeAsStringSync('''
[Platform]
profile=common
version=1.0
type=default
name=image_name
''');
      processManager.addCommand(const FakeCommand(command: <String>[
        '/tizen-studio/tools/emulator/bin/em-cli',
        'create',
        '-n',
        'flutter_emulator',
        '-p',
        'image_name',
      ]));

      final CreateEmulatorResult result = await manager.createEmulator();
      expect(result.success, isTrue);
      expect(result.emulatorName, equals('flutter_emulator'));
    });

    testWithoutContext('Can list emulators', () async {
      final File vmConfig = tizenSdk.sdkDataDirectory
          .childFile('emulator/vms/emulator_id/vm_config.xml');
      vmConfig
        ..createSync(recursive: true)
        ..writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<EmulatorConfiguration xmlns="http://www.tizen.org/em">
    <baseInformation>
        <deviceTemplate name="emulator_name" version="1.0"/>
        <diskImage profile="common" type="standard" version="9.9"/>
    </baseInformation>
</EmulatorConfiguration>
''');

      final List<Emulator> emulators = await manager.getAllAvailableEmulators();
      expect(emulators, isNotEmpty);
      expect(emulators.first.id, equals('emulator_id'));
      expect(emulators.first.name, equals('emulator_name'));
    });
  });

  group('TizenEmulator', () {
    testWithoutContext('Can launch only once', () async {
      final BufferLogger logger = BufferLogger.test();
      final TizenEmulator emulator = TizenEmulator(
        'emulator_id',
        logger: logger,
        processManager: processManager,
        tizenSdk: tizenSdk,
      );

      const List<String> launchCommand = <String>[
        '/tizen-studio/tools/emulator/bin/em-cli',
        'launch',
        '--name',
        'emulator_id',
      ];
      processManager.addCommand(const FakeCommand(command: launchCommand));
      processManager.addCommand(FakeCommand(
        command: launchCommand,
        exitCode: 1,
        stdout: '${emulator.id} is running now...',
      ));

      await emulator.launch();
      await emulator.launch();

      expect(logger.statusText, contains('emulator_id is already running.'));
    });
  });
}
