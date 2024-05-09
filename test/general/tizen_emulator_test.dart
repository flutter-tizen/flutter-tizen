// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late FakeTizenSdk tizenSdk;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();
    tizenSdk = FakeTizenSdk(fileSystem);
  });

  group('TizenEmulatorManager', () {
    late TizenEmulatorManager manager;

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
        ),
      );
    });

    testWithoutContext('Cannot create emulator if no image found', () async {
      processManager.addCommand(const FakeCommand(command: <String>[
        '/tizen-studio/tools/emulator/bin/em-cli',
        'list-vm',
        '-d',
      ]));
      processManager.addCommand(const FakeCommand(command: <String>[
        '/tizen-studio/tools/emulator/bin/em-cli',
        'list-platform',
        '-d',
      ]));

      final CreateEmulatorResult result = await manager.createEmulator();
      expect(result.success, isFalse);
      expect(result.error,
          contains('No suitable Tizen platform images are available.'));
    });

    testWithoutContext('Can create emulator without name', () async {
      processManager.addCommand(const FakeCommand(command: <String>[
        '/tizen-studio/tools/emulator/bin/em-cli',
        'list-vm',
        '-d',
      ]));
      processManager.addCommand(const FakeCommand(
        command: <String>[
          '/tizen-studio/tools/emulator/bin/em-cli',
          'list-platform',
          '-d',
        ],
        stdout: '''
platform_name
  Profile           : tizen
  Version           : 8.0
  CPU Arch          : x86
  Skin shape        : square
''',
      ));
      processManager.addCommand(const FakeCommand(
        command: <String>[
          '/tizen-studio/tools/emulator/bin/em-cli',
          'create',
          '-n',
          'flutter_emulator',
          '-p',
          'platform_name',
        ],
        stdout: 'New virtual machine is created',
      ));

      final CreateEmulatorResult result = await manager.createEmulator();
      expect(result.success, isTrue);
      expect(result.emulatorName, equals('flutter_emulator'));
    });

    testWithoutContext('Can list emulators', () async {
      processManager.addCommand(const FakeCommand(
        command: <String>[
          '/tizen-studio/tools/emulator/bin/em-cli',
          'list-vm',
          '-d',
        ],
        stdout: '''
emulator_id
  Platform          : image_name
  Template          : template_name
  Type              : standard
  CPU Arch          : x86
''',
      ));

      final List<Emulator> emulators = await manager.getAllAvailableEmulators();
      expect(emulators, isNotEmpty);
      expect(emulators.first.id, equals('emulator_id'));
      expect(emulators.first.name, equals('template_name'));
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

  group('parseEmCliOutput', () {
    testWithoutContext('Parses multiple entries', () async {
      final Map<String, Map<String, String>> parsed = parseEmCliOutput('''
entry_1
  key_1    : value_1
  key_2    : value_2

entry_2
  key_1    : value_3
  key_2    : value_4

entry_3
''');
      expect(parsed.length, equals(3));
      expect(parsed.keys.first, equals('entry_1'));

      final Map<String, String> first = parsed['entry_1']!;
      expect(first.length, equals(2));
      expect(first['key_1'], equals('value_1'));
    });

    testWithoutContext('Does not throw on corrupted input', () async {
      final Map<String, Map<String, String>> parsed = parseEmCliOutput('''
  key_1    : value_1
  key_2    : value_2
''');
      expect(parsed, isEmpty);
    });
  });
}
