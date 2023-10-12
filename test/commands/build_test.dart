// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:flutter_tizen/commands/build.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tizen/tizen_builder.dart';
import 'package:flutter_tools/src/base/analyze_size.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:test/fake.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fakes.dart';
import '../src/test_build_system.dart';
import '../src/test_flutter_command_runner.dart';

void main() {
  late FileSystem fileSystem;
  late _FakeTizenBuilder tizenBuilder;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.file('lib/main.dart').createSync(recursive: true);
    fileSystem.file('pubspec.yaml').createSync(recursive: true);
    fileSystem.file('.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"configVersion": 2, "packages": []}');

    tizenBuilder = _FakeTizenBuilder();
  });

  group('BuildTpkCommand', () {
    testUsingContext('Device profile must be specified', () async {
      final TizenBuildCommand command = TizenBuildCommand(
        fileSystem: fileSystem,
        buildSystem: TestBuildSystem.all(BuildResult(success: true)),
        osUtils: FakeOperatingSystemUtils(),
        logger: BufferLogger.test(),
        androidSdk: FakeAndroidSdk(),
      );
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
      final TizenBuildCommand command = TizenBuildCommand(
        fileSystem: fileSystem,
        buildSystem: TestBuildSystem.all(BuildResult(success: true)),
        osUtils: FakeOperatingSystemUtils(),
        logger: BufferLogger.test(),
        androidSdk: FakeAndroidSdk(),
      );
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
      final TizenBuildCommand command = TizenBuildCommand(
        fileSystem: fileSystem,
        buildSystem: TestBuildSystem.all(BuildResult(success: true)),
        osUtils: FakeOperatingSystemUtils(),
        logger: BufferLogger.test(),
        androidSdk: FakeAndroidSdk(),
      );
      fileSystem.file('test_main.dart').createSync(recursive: true);

      await createTestCommandRunner(command).run(<String>[
        'build',
        'tpk',
        '--no-pub',
        '--device-profile=common',
        '--security-profile=test_profile',
        '--target=test_main.dart',
      ]);

      expect(tizenBuilder.deviceProfile, equals('common'));
      expect(tizenBuilder.securityProfile, equals('test_profile'));
      expect(tizenBuilder.target, equals('test_main.dart'));
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      TizenBuilder: () => tizenBuilder,
    });
  });

  group('BuildModuleCommand', () {
    testUsingContext('Can compute build info', () async {
      final TizenBuildCommand command = TizenBuildCommand(
        fileSystem: fileSystem,
        buildSystem: TestBuildSystem.all(BuildResult(success: true)),
        osUtils: FakeOperatingSystemUtils(),
        logger: BufferLogger.test(),
        androidSdk: FakeAndroidSdk(),
      );

      await createTestCommandRunner(command).run(<String>[
        'build',
        'module',
        '--no-pub',
        '--device-profile=common',
        '--output-dir=../my_app/flutter',
      ]);

      expect(tizenBuilder.deviceProfile, equals('common'));
      expect(tizenBuilder.outputPath, equals('../my_app/flutter'));
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => FakeProcessManager.any(),
      TizenBuilder: () => tizenBuilder,
    });
  });
}

class _FakeTizenBuilder extends Fake implements TizenBuilder {
  _FakeTizenBuilder();

  String? deviceProfile;
  String? securityProfile;
  String? target;
  String? outputPath;

  @override
  Future<void> buildTpk({
    required FlutterProject project,
    required TizenBuildInfo tizenBuildInfo,
    required String targetFile,
    SizeAnalyzer? sizeAnalyzer,
  }) async {
    deviceProfile = tizenBuildInfo.deviceProfile;
    securityProfile = tizenBuildInfo.securityProfile;
    target = targetFile;
  }

  @override
  Future<void> buildModule({
    required FlutterProject project,
    required TizenBuildInfo tizenBuildInfo,
    required String targetFile,
    String? outputDirectory,
  }) async {
    deviceProfile = tizenBuildInfo.deviceProfile;
    target = targetFile;
    outputPath = outputDirectory;
  }
}
