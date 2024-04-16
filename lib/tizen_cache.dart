// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart' show HttpClient;
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart' show OperatingSystemUtils;
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_cache.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:process/process.dart';

const String kTizenEngineStampName = 'tizen-engine';
const String kTizenEngineRepoName = 'flutter-tizen/engine';
const String kTizenEmbedderStampName = 'tizen-embedder';
const String kTizenEmbedderRepoName = 'flutter-tizen/embedder';

mixin TizenRequiredArtifacts on FlutterCommand {
  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async =>
      <DevelopmentArtifact>{
        ...await super.requiredArtifacts,
        TizenDevelopmentArtifact.tizen,
      };
}

/// See: [DevelopmentArtifact] in `cache.dart`
class TizenDevelopmentArtifact implements DevelopmentArtifact {
  const TizenDevelopmentArtifact(this.name, {this.feature});

  @override
  final String name;

  @override
  final Feature? feature;

  static const DevelopmentArtifact tizen = TizenDevelopmentArtifact('tizen');
}

class TizenCache extends FlutterCache {
  TizenCache({
    required Logger logger,
    required FileSystem fileSystem,
    required Platform platform,
    required OperatingSystemUtils osUtils,
    required ProcessManager processManager,
    required super.projectFactory,
  }) : super(
          logger: logger,
          fileSystem: fileSystem,
          platform: platform,
          osUtils: osUtils,
        ) {
    registerArtifact(TizenEngineArtifacts(
      cache: this,
      logger: logger,
      fileSystem: fileSystem,
      platform: platform,
      osUtils: osUtils,
      processManager: processManager,
    ));
    registerArtifact(TizenEmbedderArtifacts(
      cache: this,
      logger: logger,
      fileSystem: fileSystem,
      platform: platform,
      osUtils: osUtils,
      processManager: processManager,
    ));
  }
}

abstract class TizenCachedArtifacts extends EngineCachedArtifact {
  TizenCachedArtifacts(
    String stampName,
    String repoName, {
    required Cache cache,
    required Logger logger,
    required FileSystem fileSystem,
    required Platform platform,
    required OperatingSystemUtils osUtils,
    required ProcessManager processManager,
  })  : _repoName = repoName,
        _logger = logger,
        _fileSystem = fileSystem,
        _platform = platform,
        _osUtils = osUtils,
        _processUtils =
            ProcessUtils(processManager: processManager, logger: logger),
        super(stampName, cache, TizenDevelopmentArtifact.tizen);

  final String _repoName;
  final Logger _logger;
  final FileSystem _fileSystem;
  final Platform _platform;
  final OperatingSystemUtils _osUtils;
  final ProcessUtils _processUtils;

  static const String kGithubBaseUrl = 'https://github.com';

  /// A replacement for [Cache._artifactUpdater] to work with
  /// https://github.com/flutter/flutter/pull/94178.
  @visibleForTesting
  late ArtifactUpdater artifactUpdater = () {
    return ArtifactUpdater(
      operatingSystemUtils: _osUtils,
      logger: _logger,
      fileSystem: _fileSystem,
      tempStorage: cache.getDownloadDir(),
      platform: _platform,
      httpClient: HttpClient(),
      allowedBaseUrls: <String>[
        cache.storageBaseUrl,
        cache.realmlessStorageBaseUrl,
        cache.cipdBaseUrl,
        kGithubBaseUrl,
      ],
    );
  }();

  String get shortVersion {
    if (version == null) {
      throwToolExit('Could not determine artifact revision.');
    }
    return version!.length > 7 ? version!.substring(0, 7) : version!;
  }

  @override
  List<String> getLicenseDirs() => const <String>[];

  @override
  List<String> getPackageDirs() => const <String>[];

  /// See: [EngineCachedArtifact.updateInner] in `cache.dart`
  @override
  Future<void> updateInner(
    ArtifactUpdater updater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) async {
    final String downloadUrl =
        '$kGithubBaseUrl/$_repoName/releases/download/$shortVersion';

    for (final List<String> toolsDir in getBinaryDirs()) {
      final String cacheDir = toolsDir[0];
      final String urlPath = toolsDir[1];
      final Directory artifactDir = location.childDirectory(cacheDir);

      await artifactUpdater.downloadZipArchive(
        'Downloading $cacheDir tools...',
        Uri.parse('$downloadUrl/$urlPath'),
        artifactDir,
      );

      _makeFilesExecutable(artifactDir, operatingSystemUtils);
    }
  }

  Future<void> _downloadArtifactsFromGithub(
    OperatingSystemUtils operatingSystemUtils,
    String githubRunId,
  ) async {
    _logger.printStatus('Downloading Tizen artifacts from GitHub Actions...');
    if (operatingSystemUtils.which('gh') == null) {
      throwToolExit(
          'GitHub CLI not found. Please install it first: https://cli.github.com');
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
          _repoName,
          '-n',
          basenameWithoutExtension(urlPath),
          '-D',
          artifactDir.path,
          githubRunId,
        ]);
        if (result.exitCode != 0) {
          throwToolExit(
            'Failed to download Tizen artifact from GitHub Actions.\n\n'
            '$result',
          );
        }
      } finally {
        status.stop();
      }
      _makeFilesExecutable(artifactDir, operatingSystemUtils);
    }
  }

  /// Source: [EngineCachedArtifact._makeFilesExecutable] in `cache.dart`
  void _makeFilesExecutable(
    Directory dir,
    OperatingSystemUtils operatingSystemUtils,
  ) {
    operatingSystemUtils.chmod(dir, 'a+r,a+x');
    for (final File file in dir.listSync(recursive: true).whereType<File>()) {
      if (file.basename == 'gen_snapshot') {
        operatingSystemUtils.chmod(file, 'a+r,a+x');
      }
    }
  }
}

class TizenEngineArtifacts extends TizenCachedArtifacts {
  TizenEngineArtifacts({
    required super.cache,
    required super.logger,
    required super.fileSystem,
    required super.platform,
    required super.osUtils,
    required super.processManager,
  }) : super(kTizenEngineStampName, kTizenEngineRepoName);

  /// See: [Cache.getVersionFor] in `cache.dart`
  @override
  String? get version {
    final File versionFile = _fileSystem
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('bin')
        .childDirectory('internal')
        .childFile('engine.version');
    return versionFile.existsSync()
        ? versionFile.readAsStringSync().trim()
        : null;
  }

  @override
  bool isUpToDateInner(FileSystem fileSystem) {
    // Download always happens if the following variable is set.
    if (_platform.environment['GITHUB_ENGINE_RUN_ID'] != null) {
      return false;
    }
    return super.isUpToDateInner(fileSystem);
  }

  @override
  Future<void> updateInner(
    ArtifactUpdater updater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) {
    final String? githubRunId = _platform.environment['GITHUB_ENGINE_RUN_ID'];
    if (githubRunId != null) {
      return _downloadArtifactsFromGithub(operatingSystemUtils, githubRunId);
    }
    return super.updateInner(updater, fileSystem, operatingSystemUtils);
  }

  @override
  List<List<String>> getBinaryDirs() {
    return <List<String>>[
      <String>['tizen-arm-debug', 'tizen-arm-debug.zip'],
      <String>['tizen-arm-profile', 'tizen-arm-profile.zip'],
      <String>['tizen-arm-release', 'tizen-arm-release.zip'],
      <String>['tizen-arm64-debug', 'tizen-arm64-debug.zip'],
      <String>['tizen-arm64-profile', 'tizen-arm64-profile.zip'],
      <String>['tizen-arm64-release', 'tizen-arm64-release.zip'],
      <String>['tizen-x86-debug', 'tizen-x86-debug.zip'],
      if (_platform.isWindows)
        ..._binaryDirsForHostPlatform('windows-x64')
      else if (_platform.isMacOS)
        ..._binaryDirsForHostPlatform('darwin-x64')
      else if (_platform.isLinux)
        ..._binaryDirsForHostPlatform('linux-x64'),
    ];
  }

  List<List<String>> _binaryDirsForHostPlatform(String platform) {
    return <List<String>>[
      <String>[
        'tizen-arm-profile/$platform',
        'tizen-arm-profile_$platform.zip'
      ],
      <String>[
        'tizen-arm-release/$platform',
        'tizen-arm-release_$platform.zip'
      ],
      <String>[
        'tizen-arm64-profile/$platform',
        'tizen-arm64-profile_$platform.zip'
      ],
      <String>[
        'tizen-arm64-release/$platform',
        'tizen-arm64-release_$platform.zip'
      ],
    ];
  }
}

class TizenEmbedderArtifacts extends TizenCachedArtifacts {
  TizenEmbedderArtifacts({
    required super.cache,
    required super.logger,
    required super.fileSystem,
    required super.platform,
    required super.osUtils,
    required super.processManager,
  }) : super(kTizenEmbedderStampName, kTizenEmbedderRepoName);

  @override
  String? get version {
    final File versionFile = _fileSystem
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('bin')
        .childDirectory('internal')
        .childFile('embedder.version');
    return versionFile.existsSync()
        ? versionFile.readAsStringSync().trim()
        : null;
  }

  @override
  bool isUpToDateInner(FileSystem fileSystem) {
    // Download always happens if the following variable is set.
    if (_platform.environment['GITHUB_EMBEDDER_RUN_ID'] != null) {
      return false;
    }
    return super.isUpToDateInner(fileSystem);
  }

  @override
  Future<void> updateInner(
    ArtifactUpdater updater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) {
    final String? githubRunId = _platform.environment['GITHUB_EMBEDDER_RUN_ID'];
    if (githubRunId != null) {
      return _downloadArtifactsFromGithub(operatingSystemUtils, githubRunId);
    }
    return super.updateInner(updater, fileSystem, operatingSystemUtils);
  }

  @override
  List<List<String>> getBinaryDirs() {
    return <List<String>>[
      <String>['tizen-common', 'tizen-common.zip'],
      <String>['tizen-arm/5.5', 'tizen-5.5-arm.zip'],
      <String>['tizen-arm/6.5', 'tizen-6.5-arm.zip'],
      <String>['tizen-arm/8.0', 'tizen-8-arm.zip'],
      <String>['tizen-arm64/5.5', 'tizen-5.5-arm64.zip'],
      <String>['tizen-arm64/6.5', 'tizen-6.5-arm64.zip'],
      <String>['tizen-arm64/8.0', 'tizen-8-arm64.zip'],
      <String>['tizen-x86/5.5', 'tizen-5.5-x86.zip'],
      <String>['tizen-x86/6.5', 'tizen-6.5-x86.zip'],
      <String>['tizen-x86/8.0', 'tizen-8-x86.zip'],
    ];
  }
}
