// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tizen/commands/upgrade.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/git.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_process_manager.dart';

void main() {
  late FakeProcessManager processManager;

  setUp(() {
    processManager = FakeProcessManager.empty();
  });

  TizenUpgradeCommandRunner createRunner({
    Future<int> Function(List<String> args)? runLauncher,
  }) {
    final runner = TizenUpgradeCommandRunner(
      git: Git(
        currentPlatform: FakePlatform(),
        runProcessWith: ProcessUtils(
          processManager: processManager,
          logger: BufferLogger.test(),
        ),
      ),
      runLauncher: runLauncher,
    );
    runner.workingDirectory = '/repo';
    return runner;
  }

  testUsingContext('already up to date short-circuits', () async {
    processManager.addCommands(<FakeCommand>[
      const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
      const FakeCommand(
        command: <String>['git', 'ls-remote', '--tags', '--sort=-v:refname', 'origin'],
        stdout: 'fff0001\trefs/tags/3.44.8-tizen.1.0.0\n'
            'fff0002\trefs/tags/3.44.8-tizen.1.0.0^{}\n',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '3.44.8-tizen.1.0.0^{commit}'],
        stdout: 'abc1234',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '--verify', 'HEAD'],
        stdout: 'abc1234',
      ),
    ]);
    await createRunner().run(force: false, testFlow: true, verifyOnly: false);
    expect(testLogger.statusText, contains('already up to date'));
    expect(processManager, hasNoRemainingExpectations);
  });

  testUsingContext('--verify-only reports and changes nothing', () async {
    processManager.addCommands(<FakeCommand>[
      const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
      const FakeCommand(
        command: <String>['git', 'ls-remote', '--tags', '--sort=-v:refname', 'origin'],
        stdout: 'fff0001\trefs/tags/3.44.8-tizen.1.0.0\n'
            'fff0002\trefs/tags/3.44.8-tizen.1.0.0^{}\n',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '3.44.8-tizen.1.0.0^{commit}'],
        stdout: 'def5678',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '--verify', 'HEAD'],
        stdout: 'abc1234',
      ),
      const FakeCommand(
        command: <String>['git', 'describe', '--tags', '--exact-match', 'HEAD'],
        stdout: '3.44.4-tizen.1.0.0',
      ),
      // No status/checkout: verify-only stops here.
    ]);
    await createRunner().run(force: false, testFlow: true, verifyOnly: true);
    expect(testLogger.statusText, contains('3.44.8-tizen.1.0.0'));
    expect(testLogger.statusText, contains('3.44.4-tizen.1.0.0'));
    expect(processManager, hasNoRemainingExpectations);
  });

  testUsingContext('moves the checkout, prints recovery, and finishes with precache and doctor',
      () async {
    processManager.addCommands(<FakeCommand>[
      const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
      const FakeCommand(
        command: <String>['git', 'ls-remote', '--tags', '--sort=-v:refname', 'origin'],
        stdout: 'fff0001\trefs/tags/3.44.8-tizen.1.0.0\n'
            'fff0002\trefs/tags/3.44.8-tizen.1.0.0^{}\n',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '3.44.8-tizen.1.0.0^{commit}'],
        stdout: 'def5678',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '--verify', 'HEAD'],
        stdout: 'abc1234',
      ),
      const FakeCommand(
        command: <String>['git', 'describe', '--tags', '--exact-match', 'HEAD'],
        exitCode: 128,
      ),
      const FakeCommand(
        command: <String>['git', 'status', '-s', '--untracked-files=no'],
      ),
      const FakeCommand(
        command: <String>['git', 'symbolic-ref', '-q', '--short', 'HEAD'],
        stdout: 'master',
      ),
      const FakeCommand(
        command: <String>['git', 'checkout', '--detach', 'def5678'],
      ),
    ]);
    final launcherCalls = <List<String>>[];
    await createRunner(runLauncher: (List<String> args) async {
      launcherCalls.add(args);
      return 0;
    }).run(force: false, testFlow: false, verifyOnly: false);
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

  testUsingContext('restores the welcome message state when the setup fails', () async {
    processManager.addCommands(<FakeCommand>[
      const FakeCommand(command: <String>['git', 'fetch', '--tags', '--force']),
      const FakeCommand(
        command: <String>['git', 'ls-remote', '--tags', '--sort=-v:refname', 'origin'],
        stdout: 'fff0001\trefs/tags/3.44.8-tizen.1.0.0\n'
            'fff0002\trefs/tags/3.44.8-tizen.1.0.0^{}\n',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '3.44.8-tizen.1.0.0^{commit}'],
        stdout: 'def5678',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '--verify', 'HEAD'],
        stdout: 'abc1234',
      ),
      const FakeCommand(
        command: <String>['git', 'describe', '--tags', '--exact-match', 'HEAD'],
        exitCode: 128,
      ),
      const FakeCommand(
        command: <String>['git', 'status', '-s', '--untracked-files=no'],
      ),
      const FakeCommand(
        command: <String>['git', 'symbolic-ref', '-q', '--short', 'HEAD'],
        stdout: 'master',
      ),
      const FakeCommand(
        command: <String>['git', 'checkout', '--detach', 'def5678'],
      ),
    ]);
    await expectLater(
      createRunner(runLauncher: (List<String> args) async => 1)
          .run(force: false, testFlow: false, verifyOnly: false),
      throwsToolExit(),
    );
    expect(globals.persistentToolState?.shouldRedisplayWelcomeMessage, true);
    expect(processManager, hasNoRemainingExpectations);
  }, overrides: <Type, Generator>{
    // Keep the inline setup path regardless of the host OS.
    Platform: () => FakePlatform(),
  });
}
