// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_doctor.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/user_messages.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/doctor_validator.dart';
import 'package:test/fake.dart';

import '../src/common.dart';
import '../src/context.dart';

void main() {
  FileSystem fileSystem;
  ProcessManager processManager;
  BufferLogger logger;
  _FakeTizenSdk tizenSdk;
  File dotnetCli;

  setUpAll(() {
    Cache.flutterRoot = 'flutter';
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.any();
    logger = BufferLogger.test();

    tizenSdk = _FakeTizenSdk(fileSystem.directory('/tizen-studio'));
    dotnetCli = fileSystem.file('dotnet');

    fileSystem.file('bin/internal/engine.version').createSync(recursive: true);
  });

  testUsingContext('Detects missing SDK', () async {
    final TizenValidator tizenValidator = TizenValidator(
      tizenSdk: null, // ignore: avoid_redundant_argument_values
      dotnetCli: dotnetCli,
      fileSystem: fileSystem,
      logger: logger,
      processManager: processManager,
      userMessages: UserMessages(),
    );

    final ValidationResult result = await tizenValidator.validate();
    expect(result.type, equals(ValidationType.missing));

    final ValidationMessage sdkMessage = result.messages.last;
    expect(sdkMessage.type, equals(ValidationMessageType.error));
    expect(sdkMessage.message, contains('Unable to locate Tizen SDK.'));
  });

  testUsingContext('Detects minimum required SDK version', () async {
    final TizenValidator tizenValidator = TizenValidator(
      tizenSdk: tizenSdk,
      dotnetCli: dotnetCli,
      fileSystem: fileSystem,
      logger: logger,
      processManager: processManager,
      userMessages: UserMessages(),
    );
    tizenSdk.sdkVersion = '3.7';

    final ValidationResult result = await tizenValidator.validate();
    expect(result.type, equals(ValidationType.missing));

    final ValidationMessage sdkMessage = result.messages.last;
    expect(sdkMessage.type, equals(ValidationMessageType.error));
    expect(sdkMessage.message,
        contains('A newer version of Tizen Studio is required.'));
  });

  testUsingContext('Detects missing packages', () async {
    final TizenValidator tizenValidator = TizenValidator(
      tizenSdk: tizenSdk,
      dotnetCli: dotnetCli,
      fileSystem: fileSystem,
      logger: logger,
      processManager: processManager,
      userMessages: UserMessages(),
    );

    final ValidationResult result = await tizenValidator.validate();
    expect(result.type, equals(ValidationType.partial));

    final ValidationMessage sdkMessage = result.messages.last;
    expect(sdkMessage.type, equals(ValidationMessageType.error));
    expect(sdkMessage.message, contains('To install missing packages, run:'));
  });
}

class _FakeTizenSdk extends Fake implements TizenSdk {
  _FakeTizenSdk(this.directory);

  @override
  final Directory directory;

  @override
  Directory get platformsDirectory => directory.childDirectory('platforms');

  @override
  Directory get toolsDirectory => directory.childDirectory('tools');

  @override
  String sdkVersion = '4.0';

  @override
  File get tizenCli => directory.childFile('tizen');

  @override
  File get packageManagerCli => directory.childFile('package-manager-cli');

  @override
  final String defaultGccVersion = '9.2';
}
