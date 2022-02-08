// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/user_messages.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/flutter_application_package.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:process/process.dart';

import 'tizen_tpk.dart';

/// [FlutterApplicationPackageFactory] extended for Tizen.
class TizenApplicationPackageFactory extends FlutterApplicationPackageFactory {
  TizenApplicationPackageFactory({
    required AndroidSdk androidSdk,
    required ProcessManager processManager,
    required Logger logger,
    required UserMessages userMessages,
    required FileSystem fileSystem,
  }) : super(
          androidSdk: androidSdk,
          processManager: processManager,
          logger: logger,
          userMessages: userMessages,
          fileSystem: fileSystem,
        );

  @override
  Future<ApplicationPackage?> getPackageForPlatform(
    TargetPlatform platform, {
    BuildInfo? buildInfo,
    File? applicationBinary,
  }) async {
    if (platform == TargetPlatform.tester) {
      return applicationBinary == null
          ? TizenTpk.fromProject(FlutterProject.current())
          : TizenTpk.fromTpk(applicationBinary);
    }
    return super.getPackageForPlatform(platform,
        buildInfo: buildInfo, applicationBinary: applicationBinary);
  }
}
