// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

TizenArtifacts get tizenArtifacts => context.get<TizenArtifacts>();

/// See: [getNameForTargetPlatform] in `build_info.dart`
String getArchForTargetPlatform(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android_arm64:
      return 'arm64';
    case TargetPlatform.android_x86:
      return 'x86';
    default:
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

class TizenArtifacts implements Artifacts {
  TizenArtifacts();

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

  /// See: [CachedArtifacts._getEngineArtifactsPath]
  Directory getEngineDirectory(String arch, BuildMode mode) {
    assert(mode != null, 'Need to specify a build mode.');
    return getArtifactDirectory('engine')
        .childDirectory('tizen-$arch-${mode.name}');
  }

  /// See: [CachedArtifacts._getAndroidArtifactPath] in `artifacts.dart`
  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform platform,
    BuildMode mode,
    EnvironmentType environmentType,
  }) {
    switch (artifact) {
      case Artifact.genSnapshot:
        assert(mode != BuildMode.debug,
            'Artifact $artifact only available in non-debug mode.');
        final String arch = getArchForTargetPlatform(platform);
        final String hostPlatform =
            getNameForHostPlatform(getCurrentHostPlatform());
        return getEngineDirectory(arch, mode)
            .childDirectory(hostPlatform)
            .childFile(globals.platform.isWindows
                ? 'gen_snapshot.exe'
                : 'gen_snapshot')
            .path;
      default:
        return globals.artifacts
            .getArtifactPath(artifact, platform: platform, mode: mode);
    }
  }

  @override
  String getEngineType(TargetPlatform platform, [BuildMode mode]) {
    final String arch = getArchForTargetPlatform(platform);
    return getEngineDirectory(arch, mode).basename;
  }

  @override
  bool get isLocalEngine => false;
}
