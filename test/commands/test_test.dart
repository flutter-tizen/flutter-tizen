// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:flutter_tizen/commands/test.dart';
import 'package:flutter_tizen/tizen_cache.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/test/test_wrapper.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_devices.dart';
import '../src/test_flutter_command_runner.dart';

void main() {
  FileSystem fileSystem;
  File pubspecFile;
  File packageConfigFile;
  DeviceManager deviceManager;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    final Directory projectDir = fileSystem.directory('/project');
    pubspecFile = projectDir.childFile('pubspec.yaml')
      ..createSync(recursive: true);
    packageConfigFile = projectDir.childFile('.dart_tool/package_config.json')
      ..createSync(recursive: true);
    projectDir
        .childFile('integration_test/some_integration_test.dart')
        .createSync(recursive: true);
    fileSystem.currentDirectory = projectDir.path;

    deviceManager = _FakeDeviceManager(<Device>[
      FakeDevice(
        'ephemeral',
        'ephemeral',
        ephemeral: true,
        isSupported: true,
        type: PlatformType.custom,
      ),
    ]);
  });

  testUsingContext('Requests Tizen artifacts', () async {
    final _FakeTestWrapper testWrapper = _FakeTestWrapper();
    final TizenTestCommand command = TizenTestCommand(testWrapper: testWrapper);
    final CommandRunner<void> runner = createTestCommandRunner(command);

    packageConfigFile.writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "test_api",
      "rootUri": "file:///path/to/pubcache/.pub-cache/hosted/pub.dartlang.org/test_api-0.2.19",
      "packageUri": "lib/",
      "languageVersion": "2.12"
    },
    {
      "name": "integration_test",
      "rootUri": "file:///path/to/flutter/packages/integration_test",
      "packageUri": "lib/",
      "languageVersion": "2.12"
    }
  ]
}
''');
    await runner.run(const <String>[
      'test',
      '--no-pub',
      'integration_test',
    ]);

    expect(await command.requiredArtifacts, <DevelopmentArtifact>[
      DevelopmentArtifact.androidGenSnapshot,
      TizenDevelopmentArtifact.tizen,
    ]);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    DeviceManager: () => deviceManager,
  });

  testUsingContext('Can generate entrypoint wrapper for integration test',
      () async {
    final _FakeTestWrapper testWrapper = _FakeTestWrapper();
    final TizenTestCommand command = TizenTestCommand(testWrapper: testWrapper);
    final CommandRunner<void> runner = createTestCommandRunner(command);

    final Directory pluginDir = fileSystem.directory('/some_dart_plugin');
    pluginDir.childFile('pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
flutter:
  plugin:
    platforms:
      tizen:
        dartPluginClass: SomeDartPlugin
        fileName: some_dart_plugin.dart
''');
    pubspecFile.writeAsStringSync('''
dependencies:
  some_dart_plugin:
    path: ${pluginDir.path}
''');
    packageConfigFile.writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "test_api",
      "rootUri": "file:///path/to/pubcache/.pub-cache/hosted/pub.dartlang.org/test_api-0.2.19",
      "packageUri": "lib/",
      "languageVersion": "2.12"
    },
    {
      "name": "integration_test",
      "rootUri": "file:///path/to/flutter/packages/integration_test",
      "packageUri": "lib/",
      "languageVersion": "2.12"
    },
    {
      "name": "some_dart_plugin",
      "rootUri": "${pluginDir.uri}",
      "packageUri": "lib/",
      "languageVersion": "2.12"
    }
  ]
}
''');
    await runner.run(const <String>[
      'test',
      '--no-pub',
      'integration_test',
    ]);

    final File generatedEntrypoint =
        fileSystem.file('/.tmp_rand0/rand0/some_integration_test.dart');
    expect(testWrapper.lastArgs, contains(generatedEntrypoint.path));
    expect(generatedEntrypoint.readAsStringSync(), contains('''
import 'file:///project/integration_test/some_integration_test.dart' as entrypoint;
import 'package:some_dart_plugin/some_dart_plugin.dart';

void main() {
  SomeDartPlugin.register();
  entrypoint.main();
}
'''));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    DeviceManager: () => deviceManager,
  });
}

class _FakeDeviceManager extends DeviceManager {
  _FakeDeviceManager(this._devices);

  final List<Device> _devices;

  @override
  List<DeviceDiscovery> get deviceDiscoverers => <DeviceDiscovery>[];

  @override
  Future<List<Device>> getAllConnectedDevices() async => _devices;
}

class _FakeTestWrapper implements TestWrapper {
  List<String> lastArgs;

  @override
  Future<void> main(List<String> args) async {
    lastArgs = args;
  }

  @override
  void registerPlatformPlugin(
    Iterable<Runtime> runtimes,
    FutureOr<PlatformPlugin> Function() platforms,
  ) {}
}
