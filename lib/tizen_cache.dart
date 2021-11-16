// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart' show OperatingSystemUtils;
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_cache.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
// ignore: import_of_legacy_library_into_null_safe
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:process/process.dart';

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
  const TizenDevelopmentArtifact._(this.name, {this.feature});

  @override
  final String name;

  @override
  final Feature? feature;

  static const DevelopmentArtifact tizen = TizenDevelopmentArtifact._('tizen');
}

/// Extends [FlutterCache] to register [TizenEngineArtifacts].
class TizenFlutterCache extends FlutterCache {
  TizenFlutterCache({
    required Logger logger,
    required FileSystem fileSystem,
    required Platform platform,
    required OperatingSystemUtils osUtils,
    required ProcessManager processManager,
  }) : super(
            logger: logger,
            fileSystem: fileSystem,
            platform: platform,
            osUtils: osUtils) {
    registerArtifact(TizenEngineArtifacts(
      this,
      logger: logger,
      platform: platform,
      processManager: processManager,
    ));
  }
}

class TizenEngineArtifacts extends EngineCachedArtifact {
  TizenEngineArtifacts(
    Cache cache, {
    required Logger logger,
    required Platform platform,
    required ProcessManager processManager,
  })  : _logger = logger,
        _platform = platform,
        _processUtils =
            ProcessUtils(processManager: processManager, logger: logger),
        super(
          'tizen-sdk',
          cache,
          TizenDevelopmentArtifact.tizen,
        );

  final Logger _logger;
  final Platform _platform;
  final ProcessUtils _processUtils;

  /// See: [Cache.getVersionFor] in `cache.dart`
  @override
  String? get version {
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
    if (version == null) {
      throwToolExit('Could not determine Tizen engine revision.');
    }
    return version!.length > 7 ? version!.substring(0, 7) : version!;
  }

  /// Source: [Cache.storageBaseUrl] in `cache.dart`
  String get engineBaseUrl {
    final String? overrideUrl = _platform.environment['TIZEN_ENGINE_BASE_URL'];
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
  bool isUpToDateInner(FileSystem fileSystem) {
    // Download always happens, if following variables are set.
    if (_platform.environment['TIZEN_ENGINE_GITHUB_RUN_ID'] != null ||
        _platform.environment['TIZEN_ENGINE_AZURE_BUILD_ID'] != null) {
      return false;
    }
    return super.isUpToDateInner(fileSystem);
  }

  /// See: [EngineCachedArtifact.updateInner] in `cache.dart`
  @override
  Future<void> updateInner(
    ArtifactUpdater artifactUpdater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) async {
    final String? githubRunId =
        _platform.environment['TIZEN_ENGINE_GITHUB_RUN_ID'];
    final String? azureBuildId =
        _platform.environment['TIZEN_ENGINE_AZURE_BUILD_ID'];
    if (githubRunId != null) {
      await _downloadArtifactsFromGithub(operatingSystemUtils, githubRunId);
    } else if (azureBuildId != null) {
      await _downloadArtifactsFromAzure(artifactUpdater, azureBuildId);
    } else {
      await _downloadArtifactsFromUrl(
        artifactUpdater,
        '$engineBaseUrl/download/$shortVersion',
      );
    }
  }

  Future<void> _downloadArtifactsFromUrl(
      ArtifactUpdater artifactUpdater, String downloadUrl) async {
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

  Future<void> _downloadArtifactsFromAzure(
      ArtifactUpdater updater, String buildId) async {
    _logger.printStatus(
        'Downloading Tizen engine artifacts from Azure Pipelines...');
    final String downloadUrl = await _getDownloadUrlFromAzure(buildId);
    await _downloadArtifactsFromUrl(updater, downloadUrl);
  }

  Future<void> _downloadArtifactsFromGithub(
      OperatingSystemUtils operatingSystemUtils, String ghRunId) async {
    _logger.printStatus(
        'Downloading Tizen engine artifacts from GitHub Actions...');
    if (operatingSystemUtils.which('gh') == null) {
      throwToolExit(
        'Github CLI not found. Please install it first. '
        'https://cli.github.com/',
      );
    }
    for (final List<String> toolsDir in getBinaryDirs()) {
      final String cacheDir = toolsDir[0];
      final String urlPath = toolsDir[1];
      final Directory artifactDir = location.childDirectory(cacheDir);
      final Status status =
          _logger.startProgress('Downloading $cacheDir tools...');
      try {
        if (artifactDir.existsSync()) {
          artifactDir.deleteSync(recursive: true);
        }
        artifactDir.createSync(recursive: true);
        final RunResult result = await _processUtils.run(<String>[
          'gh',
          'run',
          'download',
          '-R',
          'flutter-tizen/engine',
          '-n',
          basenameWithoutExtension(urlPath),
          '-D',
          artifactDir.path,
          ghRunId,
        ]);
        if (result.exitCode != 0) {
          throwToolExit(
            'Failed to download Tizen engine artifact from Github actions. \n\n'
            '$result',
          );
        }
      } finally {
        status.stop();
      }
    }
  }

  Future<String> _getDownloadUrlFromAzure(String buildId) async {
    final String azureRestUrl =
        'https://dev.azure.com/flutter-tizen/flutter-tizen'
        '/_apis/build/builds/$buildId/artifacts?artifactName=release';

    final http.Response response = await http.get(Uri.parse(azureRestUrl));
    if (response.statusCode == 200) {
      // ignore: avoid_dynamic_calls
      return json
          .decode(response.body)['resource']['downloadUrl']
          .toString()
          .replaceAll('content?format=zip', 'content?format=file&subPath=');
    } else {
      throwToolExit('Failed to get the download URL from $azureRestUrl.');
    }
  }
}
