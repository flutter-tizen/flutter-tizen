// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/build_info.dart';

const kUseFlutterTizenExperimental = 'USE_FLUTTER_TIZEN_EXPERIMENTAL';

/// See: [AndroidBuildInfo] in `build_info.dart`
class TizenBuildInfo {
  const TizenBuildInfo(
    this.buildInfo, {
    required this.targetArch,
    required this.deviceProfile,
    this.securityProfile,
  });

  final BuildInfo buildInfo;
  final String targetArch;
  final String deviceProfile;
  final String? securityProfile;
}

/// See: [getNameForTargetPlatform] in `build_info.dart`
String getArchForTargetPlatform(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android_arm => 'arm',
    TargetPlatform.android_arm64 => 'arm64',
    // NOTE(jsuya) : Android x86 support has been removed. Use `tester` instead of `android_x86`.
    // https://github.com/flutter/flutter/pull/169884
    TargetPlatform.tester => 'x86',
    TargetPlatform.android_x64 => 'x64',
    _ => throw ArgumentError('Unexpected platform $platform'),
  };
}

/// See: [getTargetPlatformForName] in `build_info.dart`
TargetPlatform getTargetPlatformForArch(String arch) {
  return switch (arch) {
    'arm' => TargetPlatform.android_arm,
    'arm64' => TargetPlatform.android_arm64,
    // NOTE(jsuya) : Android x86 support has been removed. Use `tester` instead of `android_x86`.
    // https://github.com/flutter/flutter/pull/169884
    'x86' => TargetPlatform.tester,
    'x86_64' => TargetPlatform.android_x64,
    'x64' => TargetPlatform.android_x64,
    _ => throw ArgumentError('Unexpected arch name $arch'),
  };
}

bool getIsTizenExperimentalEnabled(List<String> dartDefines) {
  for (final define in dartDefines) {
    if (define.startsWith('$kUseFlutterTizenExperimental=')) {
      final String value = define.split('=')[1].toLowerCase();
      if (value == 'true') {
        return true;
      } else if (value == 'false') {
        break;
      }
    }
  }
  return false;
}
