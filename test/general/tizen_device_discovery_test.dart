// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_device_discovery.dart';
import 'package:flutter_tizen/tizen_doctor.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/device.dart';

import '../src/common.dart';
import '../src/fake_process_manager.dart';
import '../src/fake_tizen_sdk.dart';
import '../src/fakes.dart';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late TizenDeviceDiscovery discovery;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();

    final tizenSdk = FakeTizenSdk(fileSystem);
    discovery = TizenDeviceDiscovery(
      tizenSdk: tizenSdk,
      tizenWorkflow: TizenWorkflow(
        tizenSdk: tizenSdk,
        operatingSystemUtils: FakeOperatingSystemUtils(),
      ),
      logger: BufferLogger.test(),
      fileSystem: fileSystem,
      processManager: processManager,
    );
  });

  testWithoutContext('pollingGetDevices can retrieve device information', () async {
    processManager.addCommand(const FakeCommand(
      command: <String>['/tizen-studio/tools/sdb', 'devices'],
      stdout: '''
* Server is not running. Start it now on port 26099 *
* Server has started successfully *
List of devices attached
192.168.0.101:26101     device          SM-R500
''',
    ));
    processManager.addCommand(const FakeCommand(
      command: <String>[
        '/tizen-studio/tools/sdb',
        '-s',
        '192.168.0.101:26101',
        'capability',
      ],
      stdout: 'cpu_arch:armv7',
    ));

    final List<Device> devices = await discovery.pollingGetDevices();
    expect(devices, hasLength(1));
    expect(devices.first.name, equals('Tizen SM-R500'));
  });

  testWithoutContext('pollingGetDevices can parse device ID containing whitespace', () async {
    processManager.addCommand(const FakeCommand(
      command: <String>['/tizen-studio/tools/sdb', 'devices'],
      stdout: '''
List of devices attached
Tizen 0                 device          80
''',
    ));
    processManager.addCommand(const FakeCommand(
      command: <String>[
        '/tizen-studio/tools/sdb',
        '-s',
        'Tizen 0',
        'capability',
      ],
      stdout: 'cpu_arch:x86',
    ));

    final List<Device> devices = await discovery.pollingGetDevices();
    expect(devices, hasLength(1));
    expect(devices.first.name, equals('Tizen 80'));
  });

  testWithoutContext('getDiagnostics can detect offline and unauthorized devices', () async {
    processManager.addCommand(const FakeCommand(
      command: <String>['/tizen-studio/tools/sdb', 'devices'],
      stdout: '''
List of devices attached
0000d85900006200        offline         device-1
192.168.0.101:26101     unauthorized    <unknown>
''',
    ));

    final List<String> diagnostics = await discovery.getDiagnostics();
    expect(diagnostics, hasLength(2));
    expect(diagnostics[0], contains('is offline'));
    expect(diagnostics[1], contains('is not authorized'));
  });
}
