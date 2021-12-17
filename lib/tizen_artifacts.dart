// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cache.dart';

class TizenArtifacts extends CachedArtifacts {
  TizenArtifacts({
    required FileSystem fileSystem,
    required Platform platform,
    required Cache cache,
    required OperatingSystemUtils operatingSystemUtils,
  })  : _cache = cache,
        super(
          fileSystem: fileSystem,
          platform: platform,
          cache: cache,
          operatingSystemUtils: operatingSystemUtils,
        );

  final Cache _cache;

  /// See: [CachedArtifacts._getEngineArtifactsPath]
  Directory _getEngineArtifactsDirectory(String arch, BuildMode mode) {
    return _cache
        .getArtifactDirectory('engine')
        .childDirectory('tizen-$arch-${mode.name}');
  }

  /// See: [CachedArtifacts._getAndroidArtifactPath] in `artifacts.dart`
  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    if (artifact == Artifact.genSnapshot) {
      assert(mode != null, 'Need to specify a build mode.');
      assert(mode != BuildMode.debug,
          'Artifact $artifact only available in non-debug mode.');
      final String arch =
          _getArchForTargetPlatform(platform ?? TargetPlatform.android_arm);
      final HostPlatform hostPlatform = getCurrentHostPlatform();
      assert(hostPlatform != HostPlatform.linux_arm64,
          'Artifact $artifact not available on Linux arm64.');
      return _getEngineArtifactsDirectory(arch, mode!)
          .childDirectory(getNameForHostPlatform(hostPlatform))
          .childFile('gen_snapshot')
          .path;
    } else {
      return super.getArtifactPath(artifact, platform: platform, mode: mode);
    }
  }
}

/// See: [getNameForTargetPlatform] in `build_info.dart`
String _getArchForTargetPlatform(TargetPlatform platform) {
  if (platform == TargetPlatform.android_arm64) {
    return 'arm64';
  } else if (platform == TargetPlatform.android_x86) {
    return 'x86';
  } else {
    return 'arm';
  }
}
