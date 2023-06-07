// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
import '../src/context.dart';
import '../src/fake_devices.dart';
import '../src/fake_process_manager.dart';
import '../src/fake_tizen_sdk.dart';

const String _kDeviceId = 'TestDeviceId';

TizenDevice _createTizenDevice({
  ProcessManager? processManager,
  FileSystem? fileSystem,
  Logger? logger,
}) {
  fileSystem ??= MemoryFileSystem.test();
  return TizenDevice(
    _kDeviceId,
    modelId: 'TestModel',
    logger: logger ?? BufferLogger.test(),
    processManager: processManager ?? FakeProcessManager.any(),
    tizenSdk: FakeTizenSdk(fileSystem),
    fileSystem: fileSystem,
  );
}

List<String> _sdbCommand(List<String> args) {
  return <String>['/tizen-studio/tools/sdb', '-s', _kDeviceId, ...args];
}

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late BufferLogger logger;

  setUp(() {
    processManager = FakeProcessManager.empty();
    fileSystem = MemoryFileSystem.test();
    logger = BufferLogger.test();
  });

  testWithoutContext('TizenDevice.startApp succeeds in debug mode', () async {
    final TizenDevice device = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    final TizenManifest tizenManifest = _FakeTizenManifest();
    final TizenTpk tpk = TizenTpk(
      applicationPackage: fileSystem.file('app.tpk')..createSync(),
      manifest: tizenManifest,
    );
    final String appId = tizenManifest.applicationId;

    processManager.addCommands(<FakeCommand>[
      FakeCommand(
        command: _sdbCommand(<String>['capability']),
        stdout: <String>[
          'cpu_arch:armv7',
          'secure_protocol:disabled',
          'platform_version:5.5',
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
        stdout: '1 file(s) pushed.',
      ),
      FakeCommand(
        command: _sdbCommand(<String>['shell', 'app_launcher', '-e', appId]),
        stdout: '... successfully launched pid = 123',
      ),
    ]);

    final FakeDeviceLogReader deviceLogReader = FakeDeviceLogReader();
    deviceLogReader
        .addLine('The Dart VM service is listening on http://127.0.0.1:12345');
    device.setLogReader(deviceLogReader);
    device.portForwarder = const NoOpDevicePortForwarder();

    final LaunchResult launchResult = await device.startApp(
      tpk,
      prebuiltApplication: true,
      debuggingOptions: DebuggingOptions.enabled(BuildInfo.debug),
      platformArgs: <String, Object>{},
    );

    expect(launchResult.started, isTrue);
    expect(launchResult.hasVmService, isTrue);
    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext(
      'TizenDevice.installApp warns if the device API version is lower than the package API version',
      () async {
    final TizenDevice device = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
      logger: logger,
    );
    final TizenTpk tpk = TizenTpk(
      applicationPackage: fileSystem.file('app.tpk')..createSync(),
      manifest: _FakeTizenManifest(),
    );

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
      FakeCommand(command: _sdbCommand(<String>['install', 'app.tpk'])),
    ]);

    expect(await device.installApp(tpk), isTrue);
    expect(
      logger.warningText,
      contains('Warning: The package API version (5.5) is greater than'),
    );
    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext(
      'TizenDevice.installApp uninstalls and reinstalls TPK if installation fails',
      () async {
    final TizenDevice device = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
      logger: logger,
    );
    final TizenTpk tpk = TizenTpk(
      applicationPackage: fileSystem.file('app.tpk')..createSync(),
      manifest: _FakeTizenManifest(),
    );

    processManager.addCommands(<FakeCommand>[
      FakeCommand(
        command: _sdbCommand(<String>['capability']),
        stdout: <String>[
          'cpu_arch:armv7',
          'secure_protocol:disabled',
          'platform_version:5.5',
        ].join('\n'),
      ),
      FakeCommand(
        command: _sdbCommand(<String>['shell', 'app_launcher', '-l']),
        stdout: '''
Application List for user 5001
User's Application
  Name    AppID
=================================================
'TestApp'     'TestApplication'
''',
      ),
      FakeCommand(
        command: _sdbCommand(<String>[
          'pull',
          '/opt/usr/apps/TestPackage/author-signature.xml',
          '/.tmp_rand0/rand0/author-signature.xml',
        ]),
        onRun: () {
          fileSystem
              .file('/.tmp_rand0/rand0/author-signature.xml')
              .createSync(recursive: true);
        },
      ),
      FakeCommand(
        command: _sdbCommand(<String>['install', 'app.tpk']),
        stdout: '''
__return_cb req_id[1] pkg_type[tpk] pkgid[TestPackage] key[install_percent] val[25]
__return_cb req_id[1] pkg_type[tpk] pkgid[TestPackage] key[error] val[-11]
__return_cb req_id[1] pkg_type[tpk] pkgid[TestPackage] key[end] val[fail]
processing result : Author certificate not match [-11] failed
''',
      ),
      FakeCommand(
        command: _sdbCommand(<String>['uninstall', 'TestPackage']),
        stdout: '''
__return_cb req_id[1] pkg_type[tpk] pkgid[TestPackage] key[install_percent] val[100]
__return_cb req_id[1] pkg_type[tpk] pkgid[TestPackage] key[end] val[ok]
''',
      ),
      FakeCommand(command: _sdbCommand(<String>['install', 'app.tpk'])),
    ]);

    expect(await device.installApp(tpk), isTrue);
    expect(logger.errorText, contains('Installing TPK failed'));
    expect(logger.statusText, contains('Uninstalling old version...'));
    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext(
      'TizenDevice.installApp installs TPK twice for TV emulators', () async {
    final TizenDevice device = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    final TizenTpk tpk = TizenTpk(
      applicationPackage: fileSystem.file('app.tpk')..createSync(),
      manifest: _FakeTizenManifest(),
    );

    processManager.addCommands(<FakeCommand>[
      FakeCommand(
        command: _sdbCommand(<String>['capability']),
        stdout: <String>[
          'cpu_arch:x86',
          'secure_protocol:enabled',
          'platform_version:5.5',
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
      'TizenDevice.isSupported returns true for supported devices', () {
    final TizenDevice wearableDevice = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    processManager.addCommand(FakeCommand(
      command: _sdbCommand(<String>['capability']),
      stdout: <String>[
        'cpu_arch:armv7',
        'secure_protocol:disabled',
        'platform_version:5.5',
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
      'TizenDevice.isSupported returns false for unsupported devices', () {
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

  testWithoutContext(
      'TizenDevicePortForwarder.forwardedPorts can list forwarded ports', () {
    final TizenDevicePortForwarder forwarder = TizenDevicePortForwarder(
      device: _createTizenDevice(
        processManager: processManager,
        fileSystem: fileSystem,
      ),
      logger: logger,
    );
    processManager.addCommand(FakeCommand(
      command: _sdbCommand(<String>['forward', '--list']),
      stdout: '''
List of port forwarding
SERIAL                  LOCAL           REMOTE
TestDeviceId            tcp:2345        tcp:1234
''',
    ));

    final List<ForwardedPort> forwardedPorts = forwarder.forwardedPorts;
    expect(forwardedPorts, hasLength(1));
    expect(forwardedPorts.first.hostPort, equals(2345));
    expect(forwardedPorts.first.devicePort, equals(1234));
    expect(processManager, hasNoRemainingExpectations);
  });

  testUsingContext('TizenDevice.dispose disposes the port forwarder', () async {
    final TizenDevice device = _createTizenDevice(
      processManager: processManager,
      fileSystem: fileSystem,
    );
    processManager.addCommands(<FakeCommand>[
      FakeCommand(
        command: _sdbCommand(<String>['forward', 'tcp:2345', 'tcp:1234']),
      ),
      FakeCommand(
        command: _sdbCommand(<String>['forward', '--list']),
        stdout: '''
List of port forwarding
SERIAL                  LOCAL           REMOTE
TestDeviceId            tcp:2345        tcp:1234
''',
      ),
      FakeCommand(
        command: _sdbCommand(<String>['forward', '--remove', 'tcp:2345']),
      ),
    ]);

    await device.portForwarder.forward(1234, hostPort: 2345);
    await device.dispose();

    expect(processManager, hasNoRemainingExpectations);
  });
}

class _FakeTizenManifest extends Fake implements TizenManifest {
  _FakeTizenManifest();

  @override
  String packageId = 'TestPackage';

  @override
  String applicationId = 'TestApplication';

  @override
  String? apiVersion = '5.5';
}
