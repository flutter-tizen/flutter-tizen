// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/build_targets/embedding.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tizen/tizen_sdk.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fake_process_manager.dart';
import '../../src/fake_tizen_sdk.dart';

void main() {
  FileSystem fileSystem;
  FakeProcessManager processManager;

  setUpAll(() {
    Cache.flutterRoot = 'flutter';
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();

    final Directory embeddingDir = fileSystem.directory('embedding/cpp');
    embeddingDir.childFile('project_def.prop')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
APPNAME = embedding_cpp
type = staticLib
''');
    embeddingDir.childFile('include/flutter.h').createSync(recursive: true);
  });

  testUsingContext('Build succeeds', () async {
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      fileSystem: fileSystem,
      logger: BufferLogger.test(),
      artifacts: Artifacts.test(),
      processManager: processManager,
    );

    await NativeEmbedding(const TizenBuildInfo(
      BuildInfo.release,
      targetArch: 'arm',
      deviceProfile: 'common',
    )).build(environment);

    final Directory outputDir =
        environment.buildDir.childDirectory('tizen_embedding');
    expect(outputDir.childFile('include/flutter.h'), exists);
    expect(outputDir.childFile('libembedding_cpp.a'), exists);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    TizenSdk: () => FakeTizenSdk(fileSystem),
  });
}
