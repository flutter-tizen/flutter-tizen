// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

/// See: [getNameForTargetPlatform] in `build_info.dart`
String getArchForTargetPlatform(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android_arm64:
      return 'aarch64';
    case TargetPlatform.android_x86:
      return 'x86';
    default:
      return 'arm';
  }
}

/// See: [getTargetPlatformForName] in `build_info.dart`
TargetPlatform getTargetPlatformForArch(String arch) {
  switch (arch) {
    case 'aarch64':
      return TargetPlatform.android_arm64;
    case 'x86':
      return TargetPlatform.android_x86;
    default:
      return TargetPlatform.android_arm;
  }
}

/// It's unable to extend [Artifacts] directly because it has no visible
/// constructor.
class TizenArtifacts extends CachedArtifacts {
  static TizenArtifacts get instance => TizenArtifacts();

  /// See: [Cache.getArtifactDirectory] in `cache.dart`
  Directory getArtifactDirectory(String name) {
    return globals.fs
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('bin')
        .childDirectory('cache')
        .childDirectory('artifacts')
        .childDirectory(name);
  }

  Directory getEngineDirectory(TargetPlatform platform, BuildMode mode) {
    return getArtifactDirectory('engine')
        .childDirectory(getEngineType(platform, mode));
  }

  /// See: [CachedArtifacts._getAndroidArtifactPath] in `cache.dart`
  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform platform,
    BuildMode mode,
  }) {
    switch (artifact) {
      case Artifact.genSnapshot:
        assert(mode != BuildMode.debug,
            'Artifact $artifact only available in non-debug mode.');
        final String hostPlatform =
            getNameForHostPlatform(getCurrentHostPlatform());
        return getEngineDirectory(platform, mode)
            .childDirectory(hostPlatform)
            .childFile('gen_snapshot')
            .path;
      default:
        return globals.artifacts
            .getArtifactPath(artifact, platform: platform, mode: mode);
    }
  }

  @override
  String getEngineType(TargetPlatform platform, [BuildMode mode]) {
    return 'tizen-${getArchForTargetPlatform(platform)}-${mode?.name}';
  }

  @override
  bool get isLocalEngine => false;
}
