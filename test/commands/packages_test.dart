// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/commands/packages.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../src/common.dart';
import '../src/context.dart';
import '../src/fakes.dart';
import '../src/package_config.dart';
import '../src/test_flutter_command_runner.dart';

void main() {
  setUpAll(Cache.disableLocking);

  Directory createProjectDirectory(String name) {
    final Directory project = globals.fs.systemTempDirectory.createTempSync(name);
    addTearDown(() => tryToDelete(project));
    project.childFile('tizen/Runner.csproj').createSync(recursive: true);
    project
        .childFile('pubspec.yaml')
        .writeAsStringSync("name: $name\nenvironment:\n  sdk: '^3.0.0'\n");
    writePackageConfigFiles(directory: project, mainLibName: name);
    return project;
  }

  Future<void> pub(List<String> args) async {
    final command = TizenPackagesCommand(
      buildSystem: globals.buildSystem,
      toolContext: const DelegatingToolContext(),
    );
    await createTestCommandRunner(command).run(<String>['pub', ...args]);
  }

  const registrant = 'tizen/flutter/GeneratedPluginRegistrant.cs';

  testUsingContext('pub get generates Tizen files only in the last --directory', () async {
    final Directory first = createProjectDirectory('first');
    final Directory second = createProjectDirectory('second');
    await pub(<String>['get', '--offline', '-C${first.path}', '--directory=${second.path}']);
    expect(first.childFile(registrant), isNot(exists));
    expect(second.childFile(registrant), exists);
  });
}
