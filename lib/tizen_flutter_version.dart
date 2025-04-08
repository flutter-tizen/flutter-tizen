// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/time.dart';

import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/version.dart';

/// An implemented [FlutterVersion] for printing Flutter-tizen version.
class TizenFlutterVersion implements FlutterVersion {
  TizenFlutterVersion({
    required FileSystem fs,
    required String flutterRoot,
  }) : flutterVersion = FlutterVersion(
          fs: fs,
          flutterRoot: flutterRoot,
        );
  final FlutterVersion flutterVersion;

  @override
  String toString() {
    final Directory workingDirectory = fs.directory(Cache.flutterRoot).parent;
    final String lastTagRevision = _runGit(
      'git rev-list --tags --max-count=1',
      workingDirectory.path,
    );

    final String flutterTizenVersion = _runGit(
      'git describe --tags $lastTagRevision',
      workingDirectory.path,
    );

    final String flutterTizenRevision = _runGit(
      'git -c log.showSignature=false log -n 1 --pretty=format:%H',
      workingDirectory.path,
    );
    return 'Flutter-Tizen $flutterTizenVersion • revision ${_shortGitRevision(flutterTizenRevision)}\n$flutterVersion';
  }

  @override
  String get channel => flutterVersion.channel;

  @override
  Future<void> checkFlutterVersionFreshness() =>
      flutterVersion.checkFlutterVersionFreshness();

  @override
  String get dartSdkVersion => flutterVersion.dartSdkVersion;

  @override
  String get devToolsVersion => flutterVersion.devToolsVersion;

  @override
  String get engineRevision => flutterVersion.engineRevision;

  @override
  String get engineRevisionShort => flutterVersion.engineRevisionShort;

  @override
  void ensureVersionFile() => flutterVersion.ensureVersionFile();

  /// See: [fetchTagsAndGetVersion] in `version.dart`
  @override
  FlutterVersion fetchTagsAndGetVersion({
    SystemClock clock = const SystemClock(),
  }) =>
      this;

  @override
  String get flutterRoot => flutterVersion.flutterRoot;

  @override
  String get frameworkAge => flutterVersion.frameworkAge;

  @override
  String get frameworkCommitDate => flutterVersion.frameworkCommitDate;

  @override
  String get frameworkRevision => flutterVersion.frameworkRevision;

  @override
  String get frameworkRevisionShort => flutterVersion.frameworkRevisionShort;

  @override
  String get frameworkVersion => flutterVersion.frameworkVersion;

  @override
  FileSystem get fs => flutterVersion.fs;

  @override
  String getBranchName({bool redactUnknownBranches = false}) =>
      flutterVersion.getBranchName();

  @override
  String getVersionString({bool redactUnknownBranches = false}) =>
      flutterVersion.getVersionString();

  @override
  GitTagVersion get gitTagVersion => flutterVersion.gitTagVersion;

  @override
  String? get repositoryUrl => flutterVersion.repositoryUrl;

  @override
  Map<String, Object> toJson() => flutterVersion.toJson();
}

/// Source: [_runGit] in `version.dart`
String _runGit(String command, String? workingDirectory) {
  return globals.processUtils
      .runSync(command.split(' '), workingDirectory: workingDirectory)
      .stdout
      .trim();
}

/// Source: [_shortGitRevision] in `version.dart`
String _shortGitRevision(String? revision) {
  if (revision == null) {
    return '';
  }
  return revision.length > 10 ? revision.substring(0, 10) : revision;
}
