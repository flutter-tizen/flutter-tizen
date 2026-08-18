// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/channel.dart';
import 'package:flutter_tools/src/git.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:path/path.dart' as path;

import '../tizen_flutter_version.dart';

/// Lists or switches flutter-tizen releases (release tags of this repo).
///
/// Source: [ChannelCommand] in `channel.dart`
class TizenChannelCommand extends ChannelCommand {
  TizenChannelCommand({
    super.verboseHelp,
    Git? git,
    String? repoRoot,
    Future<int> Function(List<String> args)? runLauncher,
  })  : _git = git,
        _repoRoot = repoRoot,
        _runLauncher = runLauncher {
    argParser.addFlag(
      'force',
      negatable: false,
      help: 'Discard local changes in the flutter-tizen checkout (including '
          'its vendored Flutter SDK and untracked files that conflict with '
          'the target release) and switch anyway.',
    );
  }

  final Git? _git;
  final String? _repoRoot;
  final Future<int> Function(List<String> args)? _runLauncher;

  Git get _gitWrapper => _git ?? globals.git;

  /// The flutter-tizen checkout root ([Cache.flutterRoot]'s parent).
  String get repoRoot => _repoRoot ?? globals.fs.directory(Cache.flutterRoot).parent.path;

  @override
  String get description => 'List or switch flutter-tizen releases.\n'
      '\n'
      'A "channel" is a release tag of the flutter-tizen repository. The\n'
      'target corresponds 1:1 to "git tag": switching to 3.44.4 checks out\n'
      'the tag named 3.44.4.\n'
      '\n'
      'Common commands:\n'
      '\n'
      ' flutter-tizen channel\n'
      '   List the flutter-tizen release tags.\n'
      '\n'
      ' flutter-tizen channel 3.44.4-tizen.1.0.0\n'
      '   Switch this checkout to the 3.44.4-tizen.1.0.0 release tag.\n'
      '\n'
      'Pass "--no-cache-artifacts" to skip downloading engine artifacts\n'
      'after the switch.';

  @override
  String get invocation => '${runner?.executableName} $name [<release-tag>]';

  @override
  bool get shouldUpdateCache => false;

  static String launcherRelativePath(Platform platform, path.Context pathContext) {
    return pathContext.join('bin', platform.isWindows ? 'flutter-tizen.bat' : 'flutter-tizen');
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    switch (argResults!.rest.length) {
      case 0:
        await _listReleases(showAll: boolArg('all'));
        return FlutterCommandResult.success();
      case 1:
        await _switchRelease(argResults!.rest.single);
        return FlutterCommandResult.success();
      default:
        throwToolExit('Too many arguments.\n$usage');
    }
  }

  /// Fetches tags (best-effort) and returns the parsed release tags plus
  /// the raw `git tag` lines.
  Future<(List<TizenGitTagVersion>, List<String>)> _fetchAndListTags() async {
    try {
      // --force so a tag re-pointed upstream does not silently stay stale.
      await _gitWrapper.run(
        <String>['fetch', '--tags', '--force'],
        throwOnError: true,
        workingDirectory: repoRoot,
      );
    } on ProcessException catch (e) {
      globals.printWarning(
        '"git fetch --tags" failed in $repoRoot; showing the releases '
        'already known locally.\n${e.message}',
      );
    }

    RunResult result;
    try {
      // Tag name plus its commit's timestamp (`*committerdate` for
      // annotated tags).
      result = await _gitWrapper.run(
        <String>[
          'tag',
          '-l',
          '--format=%(refname:short) %(committerdate:unix)%(*committerdate:unix)',
        ],
        throwOnError: true,
        workingDirectory: repoRoot,
      );
    } on ProcessException catch (e) {
      throwToolExit(
        'Could not list the flutter-tizen releases: "git tag" failed in '
        '$repoRoot.\nThis must be a git clone of the flutter-tizen '
        'repository.\n${e.message}',
      );
    }

    // Newest tagged commit first; ties keep git's output order.
    final entries = <(String, int, int)>[];
    for (final String line in result.stdout.trim().split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final int spaceIndex = trimmed.lastIndexOf(' ');
      final String name = spaceIndex == -1 ? trimmed : trimmed.substring(0, spaceIndex).trim();
      final int timestamp =
          spaceIndex == -1 ? 0 : int.tryParse(trimmed.substring(spaceIndex + 1)) ?? 0;
      entries.add((name, timestamp, entries.length));
    }
    entries.sort(((String, int, int) a, (String, int, int) b) {
      final int byTime = b.$2.compareTo(a.$2);
      return byTime != 0 ? byTime : a.$3.compareTo(b.$3);
    });

    final List<String> lines = entries.map(((String, int, int) entry) => entry.$1).toList();
    return (
      lines.map(TizenGitTagVersion.parse).whereType<TizenGitTagVersion>().toList(),
      lines,
    );
  }

  /// Resolves the commit the checkout is currently on.
  static Future<String> headCommit(Git git, String repoRoot) async {
    try {
      final RunResult result = await git.run(
        <String>['rev-parse', '--verify', 'HEAD'],
        throwOnError: true,
        workingDirectory: repoRoot,
      );
      return result.stdout.trim();
    } on ProcessException catch (e) {
      throwToolExit(
        'Unable to determine the current flutter-tizen version: could not '
        'read HEAD in $repoRoot.\n${e.message}',
      );
    }
  }

  /// The exact tag the checkout sits on, or null for a dev checkout.
  static Future<String?> currentTag(Git git, String repoRoot) async {
    try {
      final RunResult result = await git.run(
        <String>['describe', '--tags', '--exact-match', 'HEAD'],
        throwOnError: true,
        workingDirectory: repoRoot,
      );
      return result.stdout.trim();
    } on ProcessException {
      return null;
    }
  }

  /// Source: `_listChannels` in [ChannelCommand]
  Future<void> _listReleases({required bool showAll}) async {
    final (List<TizenGitTagVersion> tags, List<String> rawLines) = await _fetchAndListTags();
    final List<String> shown =
        showAll ? rawLines : tags.map((TizenGitTagVersion tag) => tag.tag).toList();
    if (shown.isEmpty) {
      globals.printStatus(
        'No flutter-tizen releases are known. If this checkout was cloned '
        'without tags, run "git fetch --tags".',
      );
      return;
    }

    final String? current = await currentTag(_gitWrapper, repoRoot);

    for (final line in shown) {
      final marker = line == current ? '(current)' : '';
      globals.printStatus('  ${line.padRight(24)}$marker'.trimRight());
    }

    if (!showAll) {
      globals.printStatus('');
      globals.printStatus('Switch with "flutter-tizen channel <release-tag>".');
    }
  }

  /// Source: `_switchChannel` in [ChannelCommand]
  Future<void> _switchRelease(String target) async {
    final (List<TizenGitTagVersion> tags, _) = await _fetchAndListTags();
    // Exact tag-name match only; no version resolution.
    final String wanted = target.trim();
    TizenGitTagVersion? release;
    for (final tag in tags) {
      if (tag.tag == wanted) {
        release = tag;
        break;
      }
    }
    if (release == null) {
      final String available = tags.map((TizenGitTagVersion tag) => '  ${tag.tag}').join('\n');
      throwToolExit(
        'No flutter-tizen release tag matches "$target".\n\n'
        '${available.isEmpty ? 'No release tags are known locally. Check your network connection.' : 'Available release tags:\n$available'}',
      );
    }

    final String commit = await peelToCommit(_gitWrapper, repoRoot, release.tag);
    final String head = await headCommit(_gitWrapper, repoRoot);
    // Before the dirty-tree guards: naming the current tag is a no-op.
    if (commit == head) {
      globals.printStatus('flutter-tizen is already on ${release.tag}.');
      return;
    }

    if (!boolArg('force') && !await isTreeClean(_gitWrapper, repoRoot)) {
      throwToolExit(
        'Your flutter-tizen checkout in $repoRoot has uncommitted changes.\n'
        'Commit or stash them first, or re-run with --force to discard them '
        'and switch anyway.',
      );
    }

    if (!boolArg('force') && !await isFlutterSdkClean(_gitWrapper, repoRoot)) {
      throwToolExit(
        'The vendored Flutter SDK in '
        '${globals.fs.path.join(repoRoot, 'flutter')} has uncommitted '
        'changes, which the post-switch setup would discard.\n'
        'Commit or stash them first, or re-run with --force to discard them '
        'and switch anyway.',
      );
    }

    final String? branch = await currentBranch(_gitWrapper, repoRoot);
    final String? pinnedFlutterVersion = readPinnedFlutterVersion(repoRoot);
    globals.printStatus('Switching flutter-tizen to ${release.tag}...');
    await checkoutDetached(_gitWrapper, repoRoot, commit, force: boolArg('force'));
    printRecovery(repoRoot: repoRoot, branch: branch, headCommit: head);
    await runPostSwitchSetup(
      repoRoot: repoRoot,
      targetTag: release.tag,
      cacheArtifacts: boolArg('cache-artifacts'),
      previousFlutterVersion: pinnedFlutterVersion,
      runLauncher: _runLauncher,
    );
    globals.printStatus('');
    globals.printStatus('Now on ${release.tag}.');
  }

  /// Peels [tag] to its commit; annotated tags resolve to tag objects
  /// otherwise.
  static Future<String> peelToCommit(Git git, String repoRoot, String tag) async {
    try {
      final RunResult result = await git.run(
        <String>['rev-parse', '$tag^{commit}'],
        throwOnError: true,
        workingDirectory: repoRoot,
      );
      return result.stdout.trim();
    } on ProcessException catch (e) {
      throwToolExit('Could not resolve the commit for $tag.\n${e.message}');
    }
  }

  /// Whether [repoRoot] has no uncommitted changes; fails closed.
  static Future<bool> isTreeClean(
    Git git,
    String repoRoot, {
    bool includeUntracked = false,
  }) async {
    try {
      final RunResult result = await git.run(
        <String>['status', '-s', if (!includeUntracked) '--untracked-files=no'],
        throwOnError: true,
        workingDirectory: repoRoot,
      );
      return result.stdout.trim().isEmpty;
    } on ProcessException catch (e) {
      throwToolExit(
        'The tool could not verify the status of the flutter-tizen checkout '
        'in $repoRoot. Ensure git is installed and in your PATH and try '
        'again.\n${e.message}',
      );
    }
  }

  /// Whether the vendored `flutter/` SDK has no uncommitted changes; the
  /// bootstrap resets and cleans it when the pinned Flutter version changes.
  /// A pristine SDK has no untracked entries (generated files are ignored),
  /// so untracked files here are user work that `git clean -xdf` would
  /// delete; ignored files cannot be guarded (bin/cache is always present).
  static Future<bool> isFlutterSdkClean(Git git, String repoRoot) async {
    final String flutterDir = globals.fs.path.join(repoRoot, 'flutter');
    if (!globals.fs.directory(globals.fs.path.join(flutterDir, '.git')).existsSync()) {
      return true;
    }
    return isTreeClean(git, flutterDir, includeUntracked: true);
  }

  /// The Flutter version this checkout pins, or null when unreadable.
  static String? readPinnedFlutterVersion(String repoRoot) {
    final File file =
        globals.fs.file(globals.fs.path.join(repoRoot, 'bin', 'internal', 'flutter.version'));
    return file.existsSync() ? file.readAsStringSync().trim() : null;
  }

  /// The branch HEAD is on, or null when already detached.
  static Future<String?> currentBranch(Git git, String repoRoot) async {
    try {
      final RunResult result = await git.run(
        <String>['symbolic-ref', '-q', '--short', 'HEAD'],
        throwOnError: true,
        workingDirectory: repoRoot,
      );
      final String branch = result.stdout.trim();
      return branch.isEmpty ? null : branch;
    } on ProcessException {
      return null;
    }
  }

  /// Detaches the worktree at [commit]; `--force` only when the user asked
  /// to discard local changes.
  static Future<void> checkoutDetached(
    Git git,
    String repoRoot,
    String commit, {
    required bool force,
  }) async {
    try {
      await git.run(
        <String>['checkout', if (force) '--force', '--detach', commit],
        throwOnError: true,
        workingDirectory: repoRoot,
      );
    } on ProcessException catch (e) {
      throwToolExit(
        'Could not switch the flutter-tizen checkout in $repoRoot to '
        '$commit.\n${e.message}'
        '${force ? '' : '\nIf untracked files conflict with the target release, re-run with --force to overwrite them.'}',
      );
    }
  }

  /// Prints the command that returns to the pre-switch state.
  static void printRecovery({
    required String repoRoot,
    required String? branch,
    required String headCommit,
  }) {
    final command = branch != null
        ? 'git -C "$repoRoot" checkout --force "$branch"'
        : 'git -C "$repoRoot" checkout --force --detach $headCommit';
    globals.printStatus('');
    globals.printStatus('If anything goes wrong, return to where you were with:');
    globals.printStatus('  $command', wrap: false);
    globals.printStatus('');
  }

  /// Re-invokes the launcher in [repoRoot] for post-checkout setup:
  /// `--version`, `precache --force` (when [cacheArtifacts]), then `doctor`.
  static Future<void> runPostSwitchSetup({
    required String repoRoot,
    required String targetTag,
    required bool cacheArtifacts,
    required String? previousFlutterVersion,
    Future<int> Function(List<String> args)? runLauncher,
  }) async {
    if (globals.platform.isWindows &&
        (previousFlutterVersion == null ||
            previousFlutterVersion != readPinnedFlutterVersion(repoRoot))) {
      // TODO(jsuya): Run inline via an exit-and-restart flow; Windows cannot
      // replace the running tool's Dart SDK in flutter/bin/cache.
      globals.printStatus(
        'The checkout is now on $targetTag. Because the pinned Flutter SDK '
        'changed, finish the setup by running:',
      );
      globals.printStatus('  flutter-tizen --version', wrap: false);
      if (cacheArtifacts) {
        globals.printStatus('  flutter-tizen precache --force', wrap: false);
      }
      globals.printStatus('  flutter-tizen doctor', wrap: false);
      return;
    }

    Future<int> launch(List<String> args) async {
      if (runLauncher != null) {
        return runLauncher(args);
      }
      return globals.processUtils.stream(
        <String>[
          launcherRelativePath(globals.platform, globals.fs.path),
          '--no-color',
          '--no-version-check',
          ...args,
        ],
        workingDirectory: repoRoot,
        allowReentrantFlutter: true,
        environment: Map<String, String>.of(globals.platform.environment),
      );
    }

    int code;
    try {
      code = await launch(<String>['--version']);
    } on ProcessException catch (e) {
      throwToolExit(
        'Switched to $targetTag, but "bin/flutter-tizen" could not be run '
        'there.\n$e\nReturn to where you were with the command above.',
      );
    }
    if (code != 0) {
      throwToolExit(
        'Switched to $targetTag, but setting up its toolchain did not '
        'finish.\nIts first run fetches the Flutter SDK and runs '
        '"pub upgrade", so a network failure and a release that does not '
        'build look the same here.\nRetry with "flutter-tizen --version". '
        'If that keeps failing, return to where you were with the command '
        'above.',
      );
    }

    if (cacheArtifacts) {
      final int code = await launch(<String>['precache', '--force']);
      if (code != 0) {
        throwToolExit(
          'Switched to $targetTag and the toolchain builds, but downloading '
          'the engine artifacts failed.\nYour checkout is on the new version '
          'and "flutter-tizen" works, so you can finish with '
          '"flutter-tizen precache --force", or go back with the command '
          'printed above.',
        );
      }
    }

    final int doctorCode = await launch(<String>['doctor']);
    if (doctorCode != 0) {
      globals.printWarning(
        'Switched to $targetTag, but "flutter-tizen doctor" reported problems.',
      );
    }
  }
}
