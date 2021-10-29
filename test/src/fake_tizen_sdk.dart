// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'fake_process_manager.dart';

class FakeTizenSdk extends TizenSdk {
  FakeTizenSdk(
    FileSystem fileSystem, {
    Logger logger,
    Platform platform,
    ProcessManager processManager,
  }) : super(
          fileSystem.directory('/tizen-studio'),
          logger: logger ?? BufferLogger.test(),
          platform: platform ?? FakePlatform(),
          processManager: processManager ?? FakeProcessManager.any(),
        );

  @override
  File get sdb => super.sdb..createSync(recursive: true);

  @override
  File get tizenCli => super.tizenCli..createSync(recursive: true);

  @override
  Rootstrap getFlutterRootstrap({
    @required String profile,
    @required String apiVersion,
    @required String arch,
  }) {
    return Rootstrap('rootstrap', directory.childDirectory('rootstrap'));
  }
}
