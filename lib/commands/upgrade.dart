// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/upgrade.dart';
import 'package:flutter_tools/src/git.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:meta/meta.dart';

import '../tizen_flutter_version.dart';
import 'channel.dart';

/// Upgrades the flutter-tizen toolchain to its newest release tag.
///
/// Source: [UpgradeCommand] in `upgrade.dart`
class TizenUpgradeCommand extends UpgradeCommand {
  TizenUpgradeCommand({required super.verboseHelp});

  @override
  String get description => 'Upgrade the flutter-tizen toolchain to the latest released version.';

  @override
  Future<FlutterCommandResult> runCommand() {
    final commandRunner = TizenUpgradeCommandRunner();
    // The repo root, not the vendored SDK at Cache.flutterRoot.
    commandRunner.workingDirectory =
        stringArg('working-directory') ?? globals.fs.directory(Cache.flutterRoot).parent.path;
    return commandRunner.run(
      force: boolArg('force'),
      testFlow: stringArg('working-directory') != null,
      verifyOnly: boolArg('verify-only'),
    );
  }
}

/// Runs the tag-based upgrade flow, without upstream's re-entrant
/// `upgrade --continue` second half.
///
/// Source: [UpgradeCommandRunner] in `upgrade.dart`
@visibleForTesting
// Subclassing the upstream runner is the seam it exposes for reuse.
// ignore: invalid_use_of_visible_for_testing_member
class TizenUpgradeCommandRunner extends UpgradeCommandRunner {
  TizenUpgradeCommandRunner({
    Git? git,
    Future<int> Function(List<String> args)? runLauncher,
  })  : _git = git,
        _runLauncher = runLauncher;

  final Git? _git;
  final Future<int> Function(List<String> args)? _runLauncher;

  Git get _gitWrapper => _git ?? globals.git;

  Future<FlutterCommandResult> run({
    required bool force,
    required bool testFlow,
    required bool verifyOnly,
  }) async {
    final TizenGitTagVersion upstream = await _fetchLatestReleaseVersion();
    final String upstreamCommit =
        await TizenChannelCommand.peelToCommit(_gitWrapper, workingDirectory!, upstream.tag);
    final String currentCommit =
        await TizenChannelCommand.headCommit(_gitWrapper, workingDirectory!);

    if (currentCommit == upstreamCommit) {
      globals.printStatus('flutter-tizen is already up to date at ${upstream.tag}.');
      return FlutterCommandResult.success();
    }

    final String? currentTag = await TizenChannelCommand.currentTag(_gitWrapper, workingDirectory!);
    final String currentLabel = currentTag ?? _shortRevision(currentCommit);

    if (verifyOnly) {
      globals.printStatus('A new version of flutter-tizen is available.\n');
      globals.printStatus('  Latest:  ${upstream.tag}', emphasis: true);
      globals.printStatus('  Current: $currentLabel\n');
      globals.printStatus('To upgrade now, run "flutter-tizen upgrade".');
      return FlutterCommandResult.success();
    }

    if (!force && !await TizenChannelCommand.isTreeClean(_gitWrapper, workingDirectory!)) {
      throwToolExit(
        'Your flutter-tizen checkout in $workingDirectory has uncommitted '
        'changes.\nCommit or stash them first, or re-run with --force to '
        'discard them and upgrade anyway.',
      );
    }

    if (!force && !await TizenChannelCommand.isFlutterSdkClean(_gitWrapper, workingDirectory!)) {
      throwToolExit(
        'The vendored Flutter SDK in '
        '${globals.fs.path.join(workingDirectory!, 'flutter')} has '
        'uncommitted changes, which the post-upgrade setup would discard.\n'
        'Commit or stash them first, or re-run with --force to discard them '
        'and upgrade anyway.',
      );
    }

    final String? branch = await TizenChannelCommand.currentBranch(_gitWrapper, workingDirectory!);
    final String? pinnedFlutterVersion =
        TizenChannelCommand.readPinnedFlutterVersion(workingDirectory!);
    globals.printStatus(
      'Upgrading flutter-tizen to ${upstream.tag} from $currentLabel in '
      '$workingDirectory...',
    );
    await TizenChannelCommand.checkoutDetached(
      _gitWrapper,
      workingDirectory!,
      upstreamCommit,
      force: force,
    );
    TizenChannelCommand.printRecovery(
      repoRoot: workingDirectory!,
      branch: branch,
      headCommit: currentCommit,
    );
    if (!testFlow) {
      globals.persistentToolState?.setShouldRedisplayWelcomeMessage(false);
      await TizenChannelCommand.runPostSwitchSetup(
        repoRoot: workingDirectory!,
        targetTag: upstream.tag,
        cacheArtifacts: true,
        previousFlutterVersion: pinnedFlutterVersion,
        runLauncher: _runLauncher,
      );
      globals.persistentToolState?.setShouldRedisplayWelcomeMessage(true);
    }
    return FlutterCommandResult.success();
  }

  /// Fetches tags and resolves the newest release tag on the remote.
  Future<TizenGitTagVersion> _fetchLatestReleaseVersion() async {
    try {
      await _gitWrapper.run(
        <String>['fetch', '--tags', '--force'],
        throwOnError: true,
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (e) {
      throwToolExit(
        '"git fetch --tags" failed in $workingDirectory, so the latest '
        'release cannot be determined.\n${e.message}',
      );
    }

    RunResult result;
    try {
      // Remote tags, not `git tag -l`: local-only tags must not become
      // targets.
      result = await _gitWrapper.run(
        <String>['ls-remote', '--tags', '--sort=-v:refname', 'origin'],
        throwOnError: true,
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (e) {
      throwToolExit(
        'Could not list the flutter-tizen releases: "git ls-remote" failed '
        'in $workingDirectory.\n${e.message}',
      );
    }
    // Lines are `<sha>\t<ref>`; annotated tags add an extra `^{}` line.
    const prefix = 'refs/tags/';
    final tags = <TizenGitTagVersion>[];
    for (final String line in result.stdout.split('\n')) {
      final int tabIndex = line.indexOf('\t');
      if (tabIndex == -1) {
        continue;
      }
      final String ref = line.substring(tabIndex + 1).trim();
      if (!ref.startsWith(prefix) || ref.endsWith('^{}')) {
        continue;
      }
      final TizenGitTagVersion? tag = TizenGitTagVersion.parse(ref.substring(prefix.length));
      if (tag != null) {
        tags.add(tag);
      }
    }
    if (tags.isEmpty) {
      throwToolExit(
        'Unable to upgrade flutter-tizen: no release tags were found on the '
        '"origin" remote.\n'
        'Make sure your flutter-tizen checkout tracks the upstream '
        'repository.',
      );
    }
    return tags.first;
  }

  String _shortRevision(String revision) =>
      revision.length > 10 ? revision.substring(0, 10) : revision;
}
