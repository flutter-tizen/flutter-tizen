// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:meta/meta.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/os.dart' show OperatingSystemUtils;
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

/// See: [DevelopmentArtifact] in `cache.dart`
class TizenDevelopmentArtifact implements DevelopmentArtifact {
  const TizenDevelopmentArtifact._(this.name, this.feature);

  @override
  final String name;

  @override
  final Feature feature;

  static const DevelopmentArtifact tizen =
      TizenDevelopmentArtifact._('tizen', null);
}

/// Extends [FlutterCache] to register [TizenEngineArtifacts].
///
/// See: [FlutterCache] in `flutter_cache.dart`
class TizenFlutterCache extends FlutterCache {
  TizenFlutterCache({
    @required Logger logger,
    @required FileSystem fileSystem,
    @required Platform platform,
    @required OperatingSystemUtils osUtils,
  }) : super(
            logger: logger,
            fileSystem: fileSystem,
            platform: platform,
            osUtils: osUtils) {
    registerArtifact(TizenEngineArtifacts(this));
  }
}

class TizenEngineArtifacts extends EngineCachedArtifact {
  TizenEngineArtifacts(Cache cache)
      : super(
          'tizen-sdk',
          cache,
          TizenDevelopmentArtifact.tizen,
        );

  @override
  String get version {
    final File versionFile = globals.fs
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('bin')
        .childDirectory('internal')
        .childFile('engine.version');
    return versionFile.existsSync()
        ? versionFile.readAsStringSync().trim()
        : null;
  }

  String get shortVersion {
    if (version != null && version.length >= 7) {
      return version.substring(0, 7);
    }
    return version;
  }

  @override
  List<List<String>> getBinaryDirs() => <List<String>>[
        <String>['tizen-common', 'tizen-common.zip'],
        <String>['tizen-x86-debug', 'tizen-x86-debug.zip'],
        <String>['tizen-arm-debug', 'tizen-arm-debug.zip'],
        <String>['tizen-arm-profile', 'tizen-arm-profile.zip'],
        <String>['tizen-arm-release', 'tizen-arm-release.zip'],
        <String>['tizen-arm64-debug', 'tizen-arm64-debug.zip'],
        <String>['tizen-arm64-profile', 'tizen-arm64-profile.zip'],
        <String>['tizen-arm64-release', 'tizen-arm64-release.zip'],
      ];

  @override
  List<String> getLicenseDirs() => const <String>[];

  @override
  List<String> getPackageDirs() => const <String>[];

  @override
  Future<void> updateInner(
    ArtifactUpdater artifactUpdater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) async {
    const String baseUrl = 'https://github.com/flutter-tizen/engine/releases';

    for (final List<String> toolsDir in getBinaryDirs()) {
      final String cacheDir = toolsDir[0];
      final String urlPath = toolsDir[1];
      final Directory dir =
          fileSystem.directory(fileSystem.path.join(location.path, cacheDir));

      await artifactUpdater.downloadZipArchive('Downloading $cacheDir tools...',
          Uri.parse('$baseUrl/download/$shortVersion/$urlPath'), dir);
    }
  }
}
