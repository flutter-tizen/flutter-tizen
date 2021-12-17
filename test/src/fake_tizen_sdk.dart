// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';
import 'package:test/test.dart';

import 'fake_process_manager.dart';

class FakeTizenSdk extends TizenSdk {
  FakeTizenSdk(
    this.fileSystem, {
    Logger logger,
    Platform platform,
    ProcessManager processManager,
    String securityProfile,
  })  : _securityProfile = securityProfile,
        super(
          fileSystem.directory('/tizen-studio'),
          logger: logger ?? BufferLogger.test(),
          platform: platform ?? FakePlatform(),
          processManager: processManager ?? FakeProcessManager.any(),
        );

  final FileSystem fileSystem;
  final String _securityProfile;

  @override
  File get sdb => super.sdb..createSync(recursive: true);

  @override
  File get tizenCli => super.tizenCli..createSync(recursive: true);

  @override
  Future<RunResult> buildApp(
    String workingDirectory, {
    Map<String, Object> build = const <String, Object>{},
    Map<String, Object> method = const <String, Object>{},
    String output,
    Map<String, Object> package = const <String, Object>{},
    String sign,
  }) async {
    final List<String> buildConfigs = method['configs'] as List<String>;
    expect(buildConfigs, isNotEmpty);

    final Directory projectDir = fileSystem.directory(workingDirectory);
    projectDir
        .childFile('${buildConfigs.first}/app.tpk')
        .createSync(recursive: true);

    return RunResult(ProcessResult(0, 0, '', ''), <String>['build-app']);
  }

  @override
  Future<RunResult> buildNative(
    String workingDirectory, {
    @required String configuration,
    @required String arch,
    String compiler,
    List<String> predefines = const <String>[],
    List<String> extraOptions = const <String>[],
    String rootstrap,
  }) async {
    final Directory projectDir = fileSystem.directory(workingDirectory);
    final Map<String, String> projectDef =
        parseIniFile(projectDir.childFile('project_def.prop'));

    final String libName = projectDef['APPNAME'];
    final String libType = projectDef['type'];
    expect(libName, isNotNull);
    expect(libType, isNotNull);

    String outPath = '$configuration/lib$libName';
    if (libType == 'staticLib') {
      outPath += '.a';
    } else if (libType == 'sharedLib') {
      outPath += '.so';
    } else {
      throw 'The project type $libType is not supported.';
    }
    projectDir.childFile(outPath).createSync(recursive: true);

    return RunResult(ProcessResult(0, 0, '', ''), <String>['build-native']);
  }

  @override
  Rootstrap getFlutterRootstrap({
    @required String profile,
    @required String apiVersion,
    @required String arch,
  }) {
    return Rootstrap('rootstrap', directory.childDirectory('rootstrap'));
  }

  @override
  SecurityProfiles get securityProfiles =>
      SecurityProfiles.test(_securityProfile);
}
