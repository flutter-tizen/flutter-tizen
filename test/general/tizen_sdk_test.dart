// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_process_manager.dart';

void main() {
  late FileSystem fileSystem;
  late BufferLogger logger;
  late FakeProcessManager processManager;
  late Directory projectDir;
  late TizenSdk tizenSdk;

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

  testUsingContext('TizenSdk.locateSdk scans the default path on macOS', () {
    expect(TizenSdk.locateSdk(), isNotNull);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    Platform: () => FakePlatform(
          operatingSystem: 'macos',
          environment: <String, String>{'HOME': '/'},
        ),
  });

  testUsingContext('TizenSdk.locateSdk scans the default path on Windows', () {
    expect(TizenSdk.locateSdk(), isNotNull);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    Platform: () => FakePlatform(
          operatingSystem: 'windows',
          environment: <String, String>{'SystemDrive': '/'},
        ),
  });

  testWithoutContext('TizenSdk.sdkVersion can parse version file', () {
    expect(tizenSdk.sdkVersion, isNull);

    tizenSdk.directory.childFile('sdk.version')
      ..createSync(recursive: true)
      ..writeAsStringSync('TIZEN_SDK_VERSION=9.9.9');

    expect(tizenSdk.sdkVersion, equals('9.9.9'));
  });

  testWithoutContext('TizenSdk.securityProfiles returns null if manifest file is missing', () {
    final Directory dataDir = fileSystem.systemTempDirectory.createTempSync('tizen-studio-data')
      ..createSync(recursive: true);
    tizenSdk.directory.childFile('sdk.info')
      ..createSync(recursive: true)
      ..writeAsStringSync('TIZEN_SDK_DATA_PATH=${dataDir.path}');

    expect(tizenSdk.securityProfiles, isNull);
  });

  testUsingContext('TizenSdk.getPathVariable prepends msys2 directory to PATH on Windows', () {
    final TizenSdk? tizenSdk = TizenSdk.locateSdk();
    expect(tizenSdk, isNotNull);
    expect(tizenSdk!.getPathVariable(), equals('/tools/msys2/usr/bin;/my/path'));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    Platform: () => FakePlatform(
          operatingSystem: 'windows',
          environment: <String, String>{'TIZEN_SDK': '/', 'PATH': '/my/path'},
        ),
  });

  testWithoutContext('TizenSdk.buildApp invokes the build-app command', () async {
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
      environment: const <String, String>{
        'PATH': '',
        'USER_CPP_OPTS': '-std=c++17',
        'test_key': 'test_value',
      },
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
      environment: <String, String>{'test_key': 'test_value'},
    );

    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext('TizenSdk.buildNative invokes the build-native command', () async {
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
      environment: const <String, String>{
        'PATH': '',
        'USER_CPP_OPTS': '-std=c++17',
        'test_key': 'test_value',
      },
    ));

    await tizenSdk.buildNative(
      projectDir.path,
      configuration: 'Debug',
      arch: 'arm',
      compiler: 'test_compiler',
      predefines: <String>['ABC'],
      extraOptions: <String>['def', 'ghi'],
      rootstrap: 'test_rootstrap',
      environment: <String, String>{'test_key': 'test_value'},
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
        '-e',
        '/path/to/extradir',
        '--',
        projectDir.path,
      ],
    ));

    await tizenSdk.package(
      projectDir.path,
      reference: '/path/to/reference/project',
      extraDir: '/path/to/extradir',
      sign: 'test_profile',
    );

    expect(processManager, hasNoRemainingExpectations);
  });

  testWithoutContext('TizenSdk.getRootstrap fails if IoT Headed SDK is missing', () {
    expect(
      () => tizenSdk.getRootstrap(
        profile: 'common',
        apiVersion: '6.0',
        arch: 'arm64',
      ),
      throwsToolExit(
        message: 'The rootstrap iot-headed-6.0-device64.core could not be found.',
      ),
    );
  });

  testWithoutContext('TizenSdk.getRootstrap falls back to IoT-Headed SDK if TV SDK is missing', () {
    tizenSdk.platformsDirectory
        .childDirectory('tizen-6.0')
        .childDirectory('iot-headed')
        .childDirectory('rootstraps')
        .childDirectory('iot-headed-6.0-device.core')
        .createSync(recursive: true);

    final Rootstrap rootstrap = tizenSdk.getRootstrap(
      profile: 'tv-samsung',
      arch: 'arm',
    );
    expect(rootstrap.id, equals('iot-headed-6.0-device.core'));
    expect(rootstrap.isValid, isTrue);
  });

  testWithoutContext('SecurityProfiles.parseFromXml can detect active profile', () async {
    final File xmlFile = fileSystem.file('profiles.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<profiles active="test_profile" version="3.1">
<profile name="test_profile"/>
</profiles>
''');

    final SecurityProfiles? profiles = SecurityProfiles.parseFromXml(xmlFile);
    expect(profiles, isNotNull);
    expect(profiles!.profiles, isNotEmpty);
    expect(profiles.active, equals('test_profile'));
  });

  testUsingContext('SecurityProfiles.parseFromXml fails on corrupted input', () {
    final File xmlFile = fileSystem.file('profiles.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('INVALID_XML');

    expect(SecurityProfiles.parseFromXml(xmlFile), isNull);
    expect(logger.errorText, isNotEmpty);
  }, overrides: <Type, Generator>{
    Logger: () => logger,
  });

  testWithoutContext('parseIniFile can parse properties from file', () {
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
