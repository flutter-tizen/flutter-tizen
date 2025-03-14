// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_cache.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:test/fake.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fakes.dart';

void main() {
  late FileSystem fileSystem;
  late Cache cache;

  setUpAll(() {
    Cache.flutterRoot = 'flutter';
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    cache = Cache.test(
      fileSystem: fileSystem,
      processManager: FakeProcessManager.any(),
    );

    fileSystem.file('bin/internal/engine.version').createSync(recursive: true);
  });

  testWithoutContext('gen_snapshot artifacts for host platform (Windows)', () {
    final TizenEngineArtifacts artifacts = TizenEngineArtifacts(
      cache: cache,
      logger: BufferLogger.test(),
      fileSystem: fileSystem,
      platform: FakePlatform(operatingSystem: 'windows'),
      osUtils: FakeOperatingSystemUtils(),
      processManager: FakeProcessManager.any(),
    );

    expect(
      artifacts.getBinaryDirs(),
      containsAll(<List<String>>[
        <String>['tizen-arm-profile/windows-x64', 'tizen-arm-profile_windows-x64.zip'],
        <String>['tizen-arm-release/windows-x64', 'tizen-arm-release_windows-x64.zip'],
        <String>['tizen-arm64-profile/windows-x64', 'tizen-arm64-profile_windows-x64.zip'],
        <String>['tizen-arm64-release/windows-x64', 'tizen-arm64-release_windows-x64.zip'],
      ]),
    );
  });

  testWithoutContext('Makes gen_snapshot binaries executable', () async {
    final TizenEngineArtifacts artifacts = TizenEngineArtifacts(
      cache: cache,
      logger: BufferLogger.test(),
      fileSystem: fileSystem,
      platform: FakePlatform(),
      osUtils: FakeOperatingSystemUtils(),
      processManager: FakeProcessManager.any(),
    );
    final _FakeArtifactUpdater artifactUpdater = _FakeArtifactUpdater();
    final FakeOperatingSystemUtils osUtils = FakeOperatingSystemUtils();

    artifacts.artifactUpdater = artifactUpdater;
    artifactUpdater.onDownload = (String message, Uri url, Directory location) {
      location.childFile('gen_snapshot').createSync(recursive: true);
    };
    await artifacts.updateInner(artifactUpdater, fileSystem, osUtils);

    final Iterable<File> genSnapshots = cache
        .getCacheArtifacts()
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.basename == 'gen_snapshot');
    expect(genSnapshots, isNotEmpty);
    expect(
      osUtils.chmods,
      containsAll(genSnapshots.map<List<String>>((File file) => <String>[file.path, 'a+r,a+x'])),
    );
  });

  testWithoutContext('Fails if GitHub CLI is not installed', () async {
    final TizenEngineArtifacts artifacts = TizenEngineArtifacts(
      cache: cache,
      logger: BufferLogger.test(),
      fileSystem: fileSystem,
      platform: FakePlatform(
        environment: <String, String>{'GITHUB_ENGINE_RUN_ID': '1234'},
      ),
      osUtils: FakeOperatingSystemUtils(),
      processManager: FakeProcessManager.any(),
    );

    await expectToolExitLater(
      artifacts.updateInner(
        _FakeArtifactUpdater(),
        fileSystem,
        FakeOperatingSystemUtils(),
      ),
      contains('GitHub CLI not found.'),
    );
  });
}

class _FakeArtifactUpdater extends Fake implements ArtifactUpdater {
  void Function(String, Uri, Directory)? onDownload;

  @override
  Future<void> downloadZipArchive(
    String message,
    Uri url,
    Directory location,
  ) async {
    onDownload?.call(message, url, location);
  }

  @override
  void removeDownloadedFiles() {}
}
