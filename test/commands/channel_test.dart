// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tizen/commands/channel.dart';
import 'package:flutter_tizen/tizen_flutter_version.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/git.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:path/path.dart' as path;

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_process_manager.dart';
import '../src/test_flutter_command_runner.dart';

/// `git tag` output, deliberately not in commit-time order to prove the sort.
const String _kTags = '3.44.8-tizen.1.0.0 1785985501\n'
    '3.44.4-tizen.1.0.0 1784512674\n'
    '3.44.4 1785985999\n'
    '3.44.1-tizen.1.1.0 1783058282\n'
    'some-branch-tag 1700000000\n';

const List<String> _kTagCommand = <String>[
  'git',
  'tag',
  '-l',
  '--format=%(refname:short) %(committerdate:unix)%(*committerdate:unix)',
];

void main() {
  late FakeProcessManager processManager;

  setUpAll(() {
    Cache.disableLocking();
  });

  tearDownAll(() {
    Cache.enableLocking();
  });

  setUp(() {
    processManager = FakeProcessManager.empty();
  });

  TizenChannelCommand createCommand({
    Future<int> Function(List<String> args)? runLauncher,
  }) {
    return TizenChannelCommand(
      git: Git(
        currentPlatform: FakePlatform(),
        runProcessWith: ProcessUtils(
          processManager: processManager,
          logger: BufferLogger.test(),
        ),
      ),
      repoRoot: '/repo',
      runLauncher: runLauncher,
    );
  }

  testUsingContext('lists release tags by tagged commit time, marking the current one', () async {
    processManager.addCommands(<FakeCommand>[
      const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
      const FakeCommand(command: _kTagCommand, stdout: _kTags),
      const FakeCommand(
        command: <String>['git', 'describe', '--tags', '--exact-match', 'HEAD'],
        stdout: '3.44.4',
      ),
    ]);
    await createTestCommandRunner(createCommand()).run(<String>['channel']);
    // Newest tagged commit first, not version order.
    final List<String> rows = testLogger.statusText
        .split('\n')
        .map((String line) => line.trim().split(' ').first)
        .where(TizenGitTagVersion.tagPattern.hasMatch)
        .toList();
    expect(rows, <String>[
      '3.44.4',
      '3.44.8-tizen.1.0.0',
      '3.44.4-tizen.1.0.0',
      '3.44.1-tizen.1.1.0',
    ]);
    expect(RegExp(r'3\.44\.4\s+\(current\)').hasMatch(testLogger.statusText), isTrue);
    expect(testLogger.statusText, isNot(contains('some-branch-tag')));
    expect(processManager, hasNoRemainingExpectations);
  });

  group('switch', () {
    void addSwitchCommands({required String tag, required String peeled}) {
      processManager.addCommands(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
        const FakeCommand(command: _kTagCommand, stdout: _kTags),
        FakeCommand(
          command: <String>['git', 'rev-parse', '$tag^{commit}'],
          stdout: peeled,
        ),
        const FakeCommand(
          command: <String>['git', 'rev-parse', '--verify', 'HEAD'],
          stdout: 'abc1234',
        ),
        const FakeCommand(
          command: <String>['git', 'status', '-s', '--untracked-files=no'],
        ),
        const FakeCommand(
          command: <String>['git', 'symbolic-ref', '-q', '--short', 'HEAD'],
          stdout: 'master',
        ),
        FakeCommand(
          command: <String>['git', 'checkout', '--detach', peeled],
        ),
      ]);
    }

    testUsingContext('switches to the exact tag given and prints recovery', () async {
      addSwitchCommands(tag: '3.44.4-tizen.1.0.0', peeled: 'def5678');
      final launcherCalls = <List<String>>[];
      final TizenChannelCommand command = createCommand(runLauncher: (List<String> args) async {
        launcherCalls.add(args);
        return 0;
      });
      await createTestCommandRunner(command).run(<String>['channel', '3.44.4-tizen.1.0.0']);
      expect(testLogger.statusText, contains('git -C "/repo" checkout --force "master"'));
      expect(launcherCalls, <List<String>>[
        <String>['--version'],
        <String>['precache', '--force'],
        <String>['doctor'],
      ]);
      expect(processManager, hasNoRemainingExpectations);
    }, overrides: <Type, Generator>{
      // Keep the inline setup path regardless of the host OS.
      Platform: () => FakePlatform(),
    });

    testUsingContext('suppresses the welcome message during post-switch setup', () async {
      addSwitchCommands(tag: '3.44.4-tizen.1.0.0', peeled: 'def5678');
      final flagDuringSetup = <bool?>[];
      final TizenChannelCommand command = createCommand(runLauncher: (List<String> args) async {
        flagDuringSetup.add(globals.persistentToolState?.shouldRedisplayWelcomeMessage);
        return 0;
      });
      await createTestCommandRunner(command).run(<String>['channel', '3.44.4-tizen.1.0.0']);
      expect(flagDuringSetup, everyElement(false));
      expect(globals.persistentToolState?.shouldRedisplayWelcomeMessage, true);
      expect(processManager, hasNoRemainingExpectations);
    }, overrides: <Type, Generator>{
      // Keep the inline setup path regardless of the host OS.
      Platform: () => FakePlatform(),
    });

    testUsingContext('a legacy bare tag is checked out as-is, not resolved', () async {
      addSwitchCommands(tag: '3.44.4', peeled: 'aaa1111');
      final TizenChannelCommand command =
          createCommand(runLauncher: (List<String> args) async => 0);
      await createTestCommandRunner(command).run(<String>['channel', '3.44.4']);
      expect(processManager, hasNoRemainingExpectations);
    });

    testUsingContext('unknown target exits listing available tags', () async {
      processManager.addCommands(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
        const FakeCommand(command: _kTagCommand, stdout: _kTags),
      ]);
      await expectToolExitLater(
        createTestCommandRunner(createCommand()).run(<String>['channel', '9.9.9']),
        contains('No flutter-tizen release tag matches "9.9.9"'),
      );
    });

    testUsingContext('--force skips the guards and passes --force to checkout', () async {
      processManager.addCommands(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
        const FakeCommand(command: _kTagCommand, stdout: _kTags),
        const FakeCommand(
          command: <String>['git', 'rev-parse', '3.44.4-tizen.1.0.0^{commit}'],
          stdout: 'def5678',
        ),
        const FakeCommand(
          command: <String>['git', 'rev-parse', '--verify', 'HEAD'],
          stdout: 'abc1234',
        ),
        // No `git status`: --force skips the dirty-tree guards.
        const FakeCommand(
          command: <String>['git', 'symbolic-ref', '-q', '--short', 'HEAD'],
          stdout: 'master',
        ),
        const FakeCommand(
          command: <String>['git', 'checkout', '--force', '--detach', 'def5678'],
        ),
      ]);
      final TizenChannelCommand command =
          createCommand(runLauncher: (List<String> args) async => 0);
      await createTestCommandRunner(command)
          .run(<String>['channel', '3.44.4-tizen.1.0.0', '--force']);
      expect(processManager, hasNoRemainingExpectations);
    });

    testUsingContext('--force discards uncommitted changes in the vendored Flutter SDK', () async {
      globals.fs.directory('/repo/flutter/.git').createSync(recursive: true);
      processManager.addCommands(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
        const FakeCommand(command: _kTagCommand, stdout: _kTags),
        const FakeCommand(
          command: <String>['git', 'rev-parse', '3.44.4-tizen.1.0.0^{commit}'],
          stdout: 'def5678',
        ),
        const FakeCommand(
          command: <String>['git', 'rev-parse', '--verify', 'HEAD'],
          stdout: 'abc1234',
        ),
        // No repo-level `git status`: --force skips that guard. The SDK is
        // still inspected because the bootstrap only resets it when the
        // pinned Flutter version changes.
        const FakeCommand(
          command: <String>['git', 'status', '-s'],
          workingDirectory: '/repo/flutter',
          stdout: '?? engine_patch.diff',
        ),
        const FakeCommand(
          command: <String>['git', 'reset', '--hard'],
          workingDirectory: '/repo/flutter',
        ),
        const FakeCommand(
          command: <String>['git', 'clean', '-df'],
          workingDirectory: '/repo/flutter',
        ),
        const FakeCommand(
          command: <String>['git', 'symbolic-ref', '-q', '--short', 'HEAD'],
          stdout: 'master',
        ),
        const FakeCommand(
          command: <String>['git', 'checkout', '--force', '--detach', 'def5678'],
        ),
      ]);
      final TizenChannelCommand command =
          createCommand(runLauncher: (List<String> args) async => 0);
      await createTestCommandRunner(command)
          .run(<String>['channel', '3.44.4-tizen.1.0.0', '--force']);
      expect(processManager, hasNoRemainingExpectations);
    }, overrides: <Type, Generator>{
      FileSystem: () => MemoryFileSystem.test(),
      ProcessManager: () => FakeProcessManager.any(),
      // Keep the inline setup path regardless of the host OS.
      Platform: () => FakePlatform(),
    });

    testUsingContext('uncommitted changes in the vendored Flutter SDK block the switch', () async {
      globals.fs.directory('/repo/flutter/.git').createSync(recursive: true);
      processManager.addCommands(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
        const FakeCommand(command: _kTagCommand, stdout: _kTags),
        const FakeCommand(
          command: <String>['git', 'rev-parse', '3.44.4-tizen.1.0.0^{commit}'],
          stdout: 'def5678',
        ),
        const FakeCommand(
          command: <String>['git', 'rev-parse', '--verify', 'HEAD'],
          stdout: 'abc1234',
        ),
        const FakeCommand(
          command: <String>['git', 'status', '-s', '--untracked-files=no'],
          workingDirectory: '/repo',
        ),
        const FakeCommand(
          command: <String>['git', 'status', '-s'],
          workingDirectory: '/repo/flutter',
          stdout: '?? engine_patch.diff',
        ),
      ]);
      await expectToolExitLater(
        createTestCommandRunner(createCommand()).run(<String>['channel', '3.44.4-tizen.1.0.0']),
        contains('vendored Flutter SDK'),
      );
    }, overrides: <Type, Generator>{
      FileSystem: () => MemoryFileSystem.test(),
      ProcessManager: () => FakeProcessManager.any(),
    });

    testUsingContext('on Windows a Flutter pin change defers setup to the next run', () async {
      addSwitchCommands(tag: '3.44.4-tizen.1.0.0', peeled: 'def5678');
      final launcherCalls = <List<String>>[];
      final TizenChannelCommand command = createCommand(runLauncher: (List<String> args) async {
        launcherCalls.add(args);
        return 0;
      });
      await createTestCommandRunner(command).run(<String>['channel', '3.44.4-tizen.1.0.0']);
      // An unreadable pinned flutter.version counts as a pin change.
      expect(launcherCalls, isEmpty);
      expect(testLogger.statusText, contains('finish the setup'));
      expect(testLogger.statusText, contains('flutter-tizen --version'));
    }, overrides: <Type, Generator>{
      Platform: () => FakePlatform(operatingSystem: 'windows'),
    });

    testUsingContext('dirty tree blocks the switch', () async {
      processManager.addCommands(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
        const FakeCommand(command: _kTagCommand, stdout: _kTags),
        const FakeCommand(
          command: <String>['git', 'rev-parse', '3.44.4-tizen.1.0.0^{commit}'],
          stdout: 'def5678',
        ),
        const FakeCommand(
          command: <String>['git', 'rev-parse', '--verify', 'HEAD'],
          stdout: 'abc1234',
        ),
        const FakeCommand(
          command: <String>['git', 'status', '-s', '--untracked-files=no'],
          stdout: ' M lib/foo.dart',
        ),
      ]);
      await expectToolExitLater(
        createTestCommandRunner(createCommand()).run(<String>['channel', '3.44.4-tizen.1.0.0']),
        contains('uncommitted changes'),
      );
    });
  });

  testWithoutContext('launcherRelativePath uses .bat on Windows', () {
    expect(
      TizenChannelCommand.launcherRelativePath(
        FakePlatform(operatingSystem: 'windows'),
        path.Context(style: path.Style.windows),
      ),
      r'bin\flutter-tizen.bat',
    );
    expect(
      TizenChannelCommand.launcherRelativePath(
        FakePlatform(),
        path.Context(style: path.Style.posix),
      ),
      'bin/flutter-tizen',
    );
  });
}
