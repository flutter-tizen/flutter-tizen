// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:convert';

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart' show OperatingSystemUtils;
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

mixin TizenRequiredArtifacts on FlutterCommand {
  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async =>
      <DevelopmentArtifact>{
        DevelopmentArtifact.androidGenSnapshot,
        TizenDevelopmentArtifact.tizen,
      };
}

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
    registerArtifact(TizenEngineArtifacts(this, platform: platform));
  }
}

class TizenEngineArtifacts extends EngineCachedArtifact {
  TizenEngineArtifacts(
    Cache cache, {
    @required Platform platform,
  })  : _platform = platform,
        super(
          'tizen-sdk',
          cache,
          TizenDevelopmentArtifact.tizen,
        );

  final Platform _platform;

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

  /// See: [Cache.storageBaseUrl] in `cache.dart`
  String get engineBaseUrl {
    final String overrideUrl = _platform.environment['TIZEN_ENGINE_BASE_URL'];
    if (overrideUrl == null) {
      return 'https://github.com/flutter-tizen/engine/releases';
    }
    try {
      Uri.parse(overrideUrl);
    } on FormatException catch (err) {
      throwToolExit('"TIZEN_ENGINE_BASE_URL" contains an invalid URI:\n$err');
    }
    return overrideUrl;
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
    final String buildId = _platform.environment['AZURE_BUILD_ID'];
    final String downloadUrl = buildId == null
        ? '$engineBaseUrl/download/$shortVersion'
        : await _getDownloadUrlFromAzure(buildId);

    for (final List<String> toolsDir in getBinaryDirs()) {
      final String cacheDir = toolsDir[0];
      final String urlPath = toolsDir[1];
      await artifactUpdater.downloadZipArchive(
        'Downloading $cacheDir tools...',
        Uri.parse('$downloadUrl/$urlPath'),
        location.childDirectory(cacheDir),
      );
    }
  }

  Future<String> _getDownloadUrlFromAzure(String buildId) async {
    final String azureRestUrl =
        'https://dev.azure.com/flutter-tizen/flutter-tizen'
        '/_apis/build/builds/$buildId/artifacts?artifactName=release';

    final http.Response response = await http.get(Uri.parse(azureRestUrl));
    if (response.statusCode == 200) {
      return json
          .decode(response.body)['resource']['downloadUrl']
          .toString()
          .replaceAll(
            'content?format=zip',
            'content?format=file&subPath=',
          );
    } else {
      throwToolExit('Failed to get the download url from $azureRestUrl');
    }
  }
}
