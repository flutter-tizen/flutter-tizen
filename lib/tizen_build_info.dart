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
  if (platform == TargetPlatform.android_arm64) {
    return 'arm64';
  } else if (platform == TargetPlatform.android_x86) {
    return 'x86';
  } else {
    return 'arm';
  }
}

/// See: [getTargetPlatformForName] in `build_info.dart`
TargetPlatform getTargetPlatformForArch(String arch) {
  switch (arch) {
    case 'arm64':
      return TargetPlatform.android_arm64;
    case 'x86':
      return TargetPlatform.android_x86;
    default:
      return TargetPlatform.android_arm;
  }
}
