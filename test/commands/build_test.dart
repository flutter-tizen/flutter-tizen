// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:flutter_tizen/commands/build.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tizen/tizen_builder.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:meta/meta.dart';
import 'package:test/fake.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/test_flutter_command_runner.dart';

void main() {
  FileSystem fileSystem;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.file('lib/main.dart').createSync(recursive: true);
    fileSystem.file('pubspec.yaml').createSync(recursive: true);
  });

  testUsingContext('Device profile must be specified', () async {
    final TizenBuildCommand command = TizenBuildCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await expectLater(
      () => runner.run(<String>['build', 'tpk', '--no-pub']),
      throwsToolExit(),
    );
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('Cannot build for x86 in release mode', () async {
    final TizenBuildCommand command = TizenBuildCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await expectLater(
      () => runner.run(<String>[
        'build',
        'tpk',
        '--no-pub',
        '--device-profile=common',
        '--target-arch=x86',
      ]),
      throwsToolExit(message: 'x86 ABI does not support AOT compilation.'),
    );
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('Can compute build info', () async {
    final TizenBuildCommand command = TizenBuildCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'build',
      'tpk',
      '--no-pub',
      '--device-profile=common',
      '--security-profile=test_profile',
    ]);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
    TizenBuilder: () => FakeTizenBuilder(
        deviceProfile: 'common', securityProfile: 'test_profile'),
  });
}

class FakeTizenBuilder extends Fake implements TizenBuilder {
  FakeTizenBuilder({
    this.deviceProfile,
    this.securityProfile,
  });

  final String deviceProfile;
  final String securityProfile;

  @override
  Future<void> buildTpk({
    @required FlutterProject project,
    @required TizenBuildInfo tizenBuildInfo,
    @required String targetFile,
  }) async {
    expect(tizenBuildInfo.deviceProfile, equals(deviceProfile));
    expect(tizenBuildInfo.securityProfile, equals(securityProfile));
  }
}
