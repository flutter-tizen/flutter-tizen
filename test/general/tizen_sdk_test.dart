// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_process_manager.dart';

void main() {
  FileSystem fileSystem;
  BufferLogger logger;
  FakeProcessManager processManager;
  Directory projectDir;
  TizenSdk tizenSdk;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    logger = BufferLogger.test();
    processManager = FakeProcessManager.empty();
    projectDir = fileSystem.currentDirectory;

    tizenSdk = TizenSdk(
      fileSystem.directory('/tizen-studio')..createSync(recursive: true),
      logger: logger,
      platform: FakePlatform(),
      processManager: processManager,
    );
  });

  testUsingContext('TizenSdk.locateSdk scans the default path on macOS',
      () async {
    expect(TizenSdk.locateSdk(), isNotNull);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    Platform: () => FakePlatform(
          operatingSystem: 'macos',
          environment: <String, String>{'HOME': '/'},
        ),
  });

  testUsingContext('TizenSdk.locateSdk scans the default path on Windows',
      () async {
    expect(TizenSdk.locateSdk(), isNotNull);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    Platform: () => FakePlatform(
          operatingSystem: 'windows',
          environment: <String, String>{'SystemDrive': '/'},
        ),
  });

  testWithoutContext('TizenSdk.sdkVersion can parse version file', () async {
    expect(tizenSdk.sdkVersion, isNull);

    tizenSdk.directory.childFile('sdk.version')
      ..createSync(recursive: true)
      ..writeAsStringSync('TIZEN_SDK_VERSION=9.9.9');

    expect(tizenSdk.sdkVersion, equals('9.9.9'));
  });

  testWithoutContext(
      'TizenSdk.securityProfiles returns null if manifest file is missing',
      () async {
    final Directory dataDir = fileSystem.systemTempDirectory
        .createTempSync('tizen-studio-data')
      ..createSync(recursive: true);
    tizenSdk.directory.childFile('sdk.info')
      ..createSync(recursive: true)
      ..writeAsStringSync('TIZEN_SDK_DATA_PATH=${dataDir.path}');

    expect(tizenSdk.securityProfiles, isNull);
  });

  testWithoutContext('TizenSdk.buildApp invokes the build-app command',
      () async {
    processManager.addCommand(FakeCommand(
      command: <String>[
        '/tizen-studio/tools/ide/bin/tizen',
        'build-app',
        '-b',
        'name: "test_build", methods: ["test_method"], targets: ["test_target"]',
        '-m',
        'name: "test_method", configs: ["Debug"], compiler: "test_compiler", predefines: ["ABC"], extraoption: ["def", "ghi"], rootstraps: [{name: "test_rootstrap", arch: "arm"}]',
        '-o',
        'output',
        '-p',
        'name: "test_package", targets: ["test_build"]',
        '-s',
        'test_profile',
        '--',
        projectDir.path,
      ],
    ));

    await tizenSdk.buildApp(
      projectDir.path,
      build: <String, Object>{
        'name': 'test_build',
        'methods': <String>['test_method'],
        'targets': <String>['test_target'],
      },
      method: <String, Object>{
        'name': 'test_method',
        'configs': <String>['Debug'],
        'compiler': 'test_compiler',
        'predefines': <String>['ABC'],
        'extraoption': <String>['def', 'ghi'],
        'rootstraps': <Map<String, String>>[
          <String, String>{'name': 'test_rootstrap', 'arch': 'arm'},
        ],
      },
      output: 'output',
      package: <String, Object>{
        'name': 'test_package',
        'targets': <String>['test_build'],
      },
      sign: 'test_profile',
    );

    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext('TizenSdk.buildNative invokes the build-native command',
      () async {
    processManager.addCommand(FakeCommand(
      command: <String>[
        '/tizen-studio/tools/ide/bin/tizen',
        'build-native',
        '-C',
        'Debug',
        '-a',
        'arm',
        '-c',
        'test_compiler',
        '-d',
        'ABC',
        '-e',
        'def ghi',
        '-r',
        'test_rootstrap',
        '--',
        projectDir.path,
      ],
    ));

    await tizenSdk.buildNative(
      projectDir.path,
      configuration: 'Debug',
      arch: 'arm',
      compiler: 'test_compiler',
      predefines: <String>['ABC'],
      extraOptions: <String>['def', 'ghi'],
      rootstrap: 'test_rootstrap',
    );

    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext('TizenSdk.package invokes the package command', () async {
    processManager.addCommand(FakeCommand(
      command: <String>[
        '/tizen-studio/tools/ide/bin/tizen',
        'package',
        '-t',
        'tpk',
        '-s',
        'test_profile',
        '-r',
        '/path/to/reference/project',
        '--',
        projectDir.path,
      ],
    ));

    await tizenSdk.package(
      projectDir.path,
      type: 'tpk',
      reference: '/path/to/reference/project',
      sign: 'test_profile',
    );

    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext(
      'TizenSdk.getFlutterRootstrap fails if IoT Headed SDK is missing',
      () async {
    expect(
      () => tizenSdk.getFlutterRootstrap(
        profile: 'common',
        apiVersion: '6.0',
        arch: 'arm64',
      ),
      throwsToolExit(
        message:
            'The rootstrap iot-headed-6.0-device64.core could not be found.',
      ),
    );
  });

  testWithoutContext(
      'TizenSdk.getFlutterRootstrap falls back to Wearable SDK if TV SDK is missing',
      () async {
    tizenSdk.platformsDirectory
        .childDirectory('tizen-4.0')
        .childDirectory('wearable')
        .childDirectory('rootstraps')
        .childDirectory('wearable-4.0-device.core')
        .createSync(recursive: true);

    final Rootstrap rootstrap = tizenSdk.getFlutterRootstrap(
      profile: 'tv',
      apiVersion: '4.0',
      arch: 'arm',
    );
    expect(rootstrap.id, equals('wearable-4.0-device.flutter'));
    expect(rootstrap.isValid, isTrue);

    expect(logger.traceText, contains('TV SDK could not be found.'));
  });

  testWithoutContext('SecurityProfiles.parseFromXml can detect active profile',
      () async {
    final File xmlFile = fileSystem.file('profiles.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<profiles active="test_profile" version="3.1">
<profile name="test_profile"/>
</profiles>
''');

    final SecurityProfiles profiles = SecurityProfiles.parseFromXml(xmlFile);
    expect(profiles.profiles, isNotEmpty);
    expect(profiles.active, equals('test_profile'));
  });

  testUsingContext('SecurityProfiles.parseFromXml fails on corrupted input',
      () async {
    final File xmlFile = fileSystem.file('profiles.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('INVALID_XML');

    expect(SecurityProfiles.parseFromXml(xmlFile), isNull);
    expect(logger.errorText, isNotEmpty);
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });

  testWithoutContext('parseIniFile can parse properties from file', () async {
    final File file = fileSystem.file('test_file.ini');
    file.writeAsStringSync('''
AAA=aaa
 BBB = bbb
CCC=ccc=ccc
#DDD=ddd
''');
    final Map<String, String> properties = parseIniFile(file);

    expect(properties['AAA'], equals('aaa'));
    expect(properties['BBB'], equals('bbb'));
    expect(properties['CCC'], equals('ccc=ccc'));
    expect(properties['DDD'], isNull);
  });
}
