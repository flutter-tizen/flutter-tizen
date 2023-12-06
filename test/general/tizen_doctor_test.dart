// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_doctor.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/user_messages.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/doctor_validator.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fakes.dart';

void main() {
  late FileSystem fileSystem;
  late BufferLogger logger;

  setUpAll(() {
    Cache.flutterRoot = 'flutter';
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    logger = BufferLogger.test();

    fileSystem.file('bin/internal/engine.version').createSync(recursive: true);
  });

  testUsingContext('Detects missing SDK', () async {
    final TizenValidator tizenValidator = TizenValidator(
      tizenSdk: null, // ignore: avoid_redundant_argument_values
      dotnetCli: fileSystem.file('dotnet'),
      fileSystem: fileSystem,
      logger: logger,
      processManager: FakeProcessManager.any(),
      userMessages: UserMessages(),
    );

    final ValidationResult result = await tizenValidator.validate();
    expect(result.type, equals(ValidationType.missing));

    final ValidationMessage sdkMessage = result.messages.last;
    expect(sdkMessage.type, equals(ValidationMessageType.error));
    expect(sdkMessage.message, contains('Unable to locate Tizen SDK.'));
  });

  testUsingContext('Detects minimum required SDK version', () async {
    final _FakeTizenSdk tizenSdk = _FakeTizenSdk(fileSystem);
    tizenSdk.sdkVersion = '4.5';

    final TizenValidator tizenValidator = TizenValidator(
      tizenSdk: tizenSdk,
      dotnetCli: fileSystem.file('dotnet'),
      fileSystem: fileSystem,
      logger: logger,
      processManager: FakeProcessManager.any(),
      userMessages: UserMessages(),
    );

    final ValidationResult result = await tizenValidator.validate();
    expect(result.type, equals(ValidationType.missing));

    final ValidationMessage sdkMessage = result.messages.last;
    expect(sdkMessage.type, equals(ValidationMessageType.error));
    expect(sdkMessage.message,
        contains('A newer version of Tizen Studio is required.'));
  });

  testUsingContext('Detects missing packages', () async {
    final TizenValidator tizenValidator = TizenValidator(
      tizenSdk: _FakeTizenSdk(fileSystem),
      dotnetCli: fileSystem.file('dotnet'),
      fileSystem: fileSystem,
      logger: logger,
      processManager: FakeProcessManager.any(),
      userMessages: UserMessages(),
    );

    final ValidationResult result = await tizenValidator.validate();
    expect(result.type, equals(ValidationType.partial));

    final ValidationMessage sdkMessage = result.messages.last;
    expect(sdkMessage.type, equals(ValidationMessageType.error));
    expect(sdkMessage.message, contains('To install missing packages, run:'));
  });

  testWithoutContext('TizenWorkflow handles null SDK', () {
    final TizenWorkflow tizenWorkflow = TizenWorkflow(
      tizenSdk: null, // ignore: avoid_redundant_argument_values
      operatingSystemUtils: FakeOperatingSystemUtils(),
    );

    expect(tizenWorkflow.canLaunchDevices, isFalse);
    expect(tizenWorkflow.canListDevices, isFalse);
    expect(tizenWorkflow.canListEmulators, isFalse);
  });

  testWithoutContext('TizenWorkflow can list emulators', () {
    final _FakeTizenSdk tizenSdk = _FakeTizenSdk(fileSystem);
    final TizenWorkflow tizenWorkflow = TizenWorkflow(
      tizenSdk: tizenSdk,
      operatingSystemUtils: FakeOperatingSystemUtils(),
    );

    expect(tizenWorkflow.canLaunchDevices, isTrue);
    expect(tizenWorkflow.canListDevices, isTrue);
    expect(tizenWorkflow.canListEmulators, isFalse);

    tizenSdk.emCli.createSync(recursive: true);
    expect(tizenWorkflow.canListEmulators, isTrue);
  });
}

class _FakeTizenSdk extends TizenSdk {
  _FakeTizenSdk(FileSystem fileSystem)
      : super(
          fileSystem.directory('/tizen-studio'),
          logger: BufferLogger.test(),
          platform: FakePlatform(),
          processManager: FakeProcessManager.any(),
        );

  @override
  String? sdkVersion = '5.0';
}
