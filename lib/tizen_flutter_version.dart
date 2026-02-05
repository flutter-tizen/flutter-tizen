// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/time.dart';

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
          git: globals.git,
        );
  final FlutterVersion flutterVersion;

  var _flutterTizenLatestRevision = '';
  String get flutterTizenLatestRevision {
    if (_flutterTizenLatestRevision.isEmpty) {
      final Directory workingDirectory = fs.directory(flutterRoot).parent;
      _flutterTizenLatestRevision = globals.git
          .logSync(<String>['-n', '1', '--pretty=format:%H'],
              workingDirectory: workingDirectory.path)
          .stdout
          .trim();
    }
    return _flutterTizenLatestRevision;
  }

  @override
  String toString() {
    return 'Flutter-Tizen • revision ${_shortGitRevision(flutterTizenLatestRevision)}\n$flutterVersion';
  }

  @override
  String get channel => flutterVersion.channel;

  @override
  Future<void> checkFlutterVersionFreshness() => flutterVersion.checkFlutterVersionFreshness();

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
      flutterVersion.getBranchName(redactUnknownBranches: redactUnknownBranches);

  @override
  String getVersionString({bool redactUnknownBranches = false}) =>
      flutterVersion.getVersionString(redactUnknownBranches: redactUnknownBranches);

  @override
  GitTagVersion get gitTagVersion => flutterVersion.gitTagVersion;

  @override
  String? get repositoryUrl => flutterVersion.repositoryUrl;

  @override
  Map<String, Object> toJson() => flutterVersion.toJson();

  @override
  String get engineAge => flutterVersion.engineAge;

  @override
  String? get engineCommitDate => flutterVersion.engineCommitDate;

  @override
  String? get engineBuildDate => flutterVersion.engineBuildDate;

  @override
  String? get engineContentHash => flutterVersion.engineContentHash;
}

// NOTE: Use globals.git (Git wrapper) for running git commands to ensure
// consistent behavior across platforms (e.g. Windows/MSYS noglob).

/// Source: [_shortGitRevision] in `version.dart`
String _shortGitRevision(String revision) {
  return revision.length > 10 ? revision.substring(0, 10) : revision;
}
