// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/build_info.dart';

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
    TargetPlatform.android_x86 => 'x86',
    _ => throw ArgumentError('Unexpected platform $platform'),
  };
}

/// See: [getTargetPlatformForName] in `build_info.dart`
TargetPlatform getTargetPlatformForArch(String arch) {
  return switch (arch) {
    'arm' => TargetPlatform.android_arm,
    'arm64' => TargetPlatform.android_arm64,
    'x86' => TargetPlatform.android_x86,
    _ => throw ArgumentError('Unexpected arch name $arch'),
  };
}
