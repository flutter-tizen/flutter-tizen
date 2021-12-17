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
import '../src/test_flutter_command_runner.dart';

void main() {
  FileSystem fileSystem;
  FakeProcessManager processManager;
  TizenSdk tizenSdk;
  Directory projectDir;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();
    tizenSdk = TizenSdk(
      fileSystem.directory('/tizen-studio'),
      logger: BufferLogger.test(),
      platform: FakePlatform(),
      processManager: processManager,
    );
    projectDir = fileSystem.currentDirectory;
  });

  testWithoutContext('Build native app', () async {
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

  testWithoutContext('Build native library', () async {
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
}
