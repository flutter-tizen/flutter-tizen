// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:flutter_tizen/commands/test.dart';
import 'package:flutter_tizen/tizen_cache.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/test/test_wrapper.dart';

import '../src/context.dart';
import '../src/fake_devices.dart';
import '../src/package_config.dart';
import '../src/test_flutter_command_runner.dart';

void main() {
  late FileSystem fileSystem;
  late File pubspecFile;
  late File packageConfigFile;
  late DeviceManager deviceManager;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    pubspecFile = fileSystem.file('pubspec.yaml')..createSync(recursive: true);
    packageConfigFile = fileSystem.file('.dart_tool/package_config.json')
      ..createSync(recursive: true);
    fileSystem.file('integration_test/some_integration_test.dart').createSync(recursive: true);

    deviceManager = _FakeDeviceManager(<Device>[
      FakeDevice('ephemeral', 'ephemeral', type: PlatformType.custom),
    ]);
  });

  testUsingContext('Integration test requires Tizen artifacts', () async {
    final testWrapper = _FakeTestWrapper();
    final command = TizenTestCommand(testWrapper: testWrapper);
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

    expect(
      await command.requiredArtifacts,
      contains(TizenDevelopmentArtifact.tizen),
    );
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    DeviceManager: () => deviceManager,
  }, testOn: 'posix');

  testUsingContext('Can generate entrypoint wrapper for integration test', () async {
    final testWrapper = _FakeTestWrapper();
    final command = TizenTestCommand(testWrapper: testWrapper);
    final CommandRunner<void> runner = createTestCommandRunner(command);
    final Directory pluginDir = fileSystem.currentDirectory;

    // To generate .dart_tool/package_graph.json
    writePackageConfigFiles(mainLibName: 'some_dart_plugin', directory: pluginDir);

    pubspecFile.writeAsStringSync('''
name: some_dart_plugin
flutter:
  plugin:
    platforms:
      tizen:
        dartPluginClass: SomeDartPlugin
        fileName: some_dart_plugin.dart
dependencies:
  some_dart_plugin:
    path: ${pluginDir.path}
dev_dependencies:
  flutter_test:
    sdk: flutter
  test: any
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
    expect(testWrapper.lastArgs, contains(generatedEntrypoint.uri.toString()));
    expect(generatedEntrypoint.readAsStringSync(), contains('''
//
// Generated file. Do not edit.
//
// @dart = 2.12

import 'file:///integration_test/some_integration_test.dart' as entrypoint;
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
  }, testOn: 'posix');
}

class _FakeDeviceManager extends DeviceManager {
  _FakeDeviceManager(this._devices) : super(logger: BufferLogger.test());

  final List<Device> _devices;

  @override
  List<DeviceDiscovery> get deviceDiscoverers => <DeviceDiscovery>[];

  @override
  Future<List<Device>> getAllDevices({DeviceDiscoveryFilter? filter}) async {
    if (filter?.deviceConnectionInterface == DeviceConnectionInterface.wireless) {
      return <Device>[];
    }
    return _devices;
  }
}

class _FakeTestWrapper implements TestWrapper {
  var lastArgs = <String>[];

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
