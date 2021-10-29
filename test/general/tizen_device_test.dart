// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_device.dart';
import 'package:flutter_tizen/tizen_tpk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/device_port_forwarder.dart';
import 'package:test/fake.dart';

import '../src/common.dart';
import '../src/fake_devices.dart';
import '../src/fake_process_manager.dart';
import '../src/fake_tizen_sdk.dart';

const String _kDeviceId = 'TestDeviceId';

TizenDevice _createTizenDevice({
  ProcessManager processManager,
  FileSystem fileSystem,
}) {
  fileSystem ??= MemoryFileSystem.test();
  return TizenDevice(
    _kDeviceId,
    modelId: 'TestModel',
    logger: BufferLogger.test(),
    processManager: processManager ?? FakeProcessManager.any(),
    tizenSdk: FakeTizenSdk(fileSystem),
    fileSystem: fileSystem,
  );
}

List<String> _sdbCommand(List<String> args) {
  return <String>['/tizen-studio/tools/sdb', '-s', _kDeviceId, ...args];
}

void main() {
  FileSystem fileSystem;
  FakeProcessManager processManager;

  setUp(() {
    processManager = FakeProcessManager.empty();
    fileSystem = MemoryFileSystem.test();
  });

  testWithoutContext('TizenDevice.startApp succeeds in debug mode', () async {
    final TizenDevice device = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    final TizenManifest tizenManifest = _FakeTizenManifest();
    final TizenTpk tpk = TizenTpk(
      file: fileSystem.file('app.tpk')..createSync(),
      manifest: tizenManifest,
    );
    final String appId = tizenManifest.applicationId;

    processManager.addCommands(<FakeCommand>[
      FakeCommand(
        command: _sdbCommand(<String>['capability']),
        stdout: <String>[
          'cpu_arch:armv7',
          'secure_protocol:disabled',
          'platform_version:4.0',
        ].join('\n'),
      ),
      FakeCommand(
        command: _sdbCommand(<String>['shell', 'app_launcher', '-l']),
      ),
      FakeCommand(
        command: _sdbCommand(<String>['shell', 'app_launcher', '-l']),
      ),
      FakeCommand(command: _sdbCommand(<String>['install', 'app.tpk'])),
      FakeCommand(
        command: _sdbCommand(<String>[
          'push',
          '/.tmp_rand0/rand0/$appId.rpm',
          '/home/owner/share/tmp/sdk_tools/$appId.rpm',
        ]),
      ),
      FakeCommand(
        command: _sdbCommand(<String>['shell', 'app_launcher', '-s', appId]),
        stdout: '... successfully launched pid = 123',
      ),
    ]);

    final FakeDeviceLogReader deviceLogReader = FakeDeviceLogReader();
    deviceLogReader.addLine('Observatory listening on http://127.0.0.1:12345');
    device.setLogReader(deviceLogReader);
    device.portForwarder = const NoOpDevicePortForwarder();

    final LaunchResult launchResult = await device.startApp(
      tpk,
      prebuiltApplication: true,
      debuggingOptions: DebuggingOptions.enabled(BuildInfo.debug),
      platformArgs: <String, dynamic>{},
    );

    expect(launchResult.started, isTrue);
    expect(launchResult.hasObservatory, isTrue);
    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext(
      'TizenDevice.installApp installs TPK twice for TV emulators', () async {
    final TizenDevice device = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    final TizenTpk tpk = TizenTpk(
      file: fileSystem.file('app.tpk')..createSync(),
      manifest: _FakeTizenManifest(),
    );

    processManager.addCommands(<FakeCommand>[
      FakeCommand(
        command: _sdbCommand(<String>['capability']),
        stdout: <String>[
          'cpu_arch:x86',
          'secure_protocol:enabled',
          'platform_version:4.0',
        ].join('\n'),
      ),
      FakeCommand(command: _sdbCommand(<String>['shell', '0', 'applist'])),
      FakeCommand(command: _sdbCommand(<String>['install', 'app.tpk'])),
      FakeCommand(command: _sdbCommand(<String>['install', 'app.tpk'])),
    ]);

    expect(await device.isLocalEmulator, isTrue);
    expect(device.usesSecureProtocol, isTrue);

    expect(await device.installApp(tpk), isTrue);
    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext(
      'TizenDevice.isSupported returns true for supported devices', () async {
    final TizenDevice wearableDevice = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    processManager.addCommand(FakeCommand(
      command: _sdbCommand(<String>['capability']),
      stdout: <String>[
        'cpu_arch:armv7',
        'secure_protocol:disabled',
        'platform_version:4.0',
        'profile_name:wearable'
      ].join('\n'),
    ));
    expect(wearableDevice.deviceProfile, equals('wearable'));
    expect(wearableDevice.isSupported(), isTrue);

    final TizenDevice tvDevice = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    processManager.addCommand(FakeCommand(
      command: _sdbCommand(<String>['capability']),
      stdout: <String>[
        'cpu_arch:x86',
        'secure_protocol:enabled',
        'platform_version:6.0',
        'profile_name:tv'
      ].join('\n'),
    ));
    expect(tvDevice.deviceProfile, equals('tv'));
    expect(tvDevice.isSupported(), isTrue);
  });

  testWithoutContext(
      'TizenDevice.isSupported returns false for unsupported devices',
      () async {
    final TizenDevice mobileDevice = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    processManager.addCommand(FakeCommand(
      command: _sdbCommand(<String>['capability']),
      stdout: <String>[
        'cpu_arch:armv7',
        'secure_protocol:disabled',
        'platform_version:4.0',
        'profile_name:mobile'
      ].join('\n'),
    ));
    expect(mobileDevice.deviceProfile, equals('mobile'));
    expect(mobileDevice.isSupported(), isFalse);

    final TizenDevice tvDevice = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    processManager.addCommand(FakeCommand(
      command: _sdbCommand(<String>['capability']),
      stdout: <String>[
        'cpu_arch:armv7',
        'secure_protocol:enabled',
        'platform_version:5.5',
        'profile_name:tv'
      ].join('\n'),
    ));
    expect(tvDevice.deviceProfile, equals('tv'));
    expect(tvDevice.isSupported(), isFalse);
  });
}

class _FakeTizenManifest extends Fake implements TizenManifest {
  _FakeTizenManifest();

  @override
  String packageId = 'TestPackage';

  @override
  String applicationId = 'TestApplication';

  @override
  String apiVersion;
}
