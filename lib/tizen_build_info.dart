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
