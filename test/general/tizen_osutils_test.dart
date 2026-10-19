// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:archive/archive.dart';
import 'package:file/memory.dart';
import 'package:flutter_tizen/tizen_osutils.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';

import '../src/common.dart';
import '../src/fake_process_manager.dart';

void main() {
  late FileSystem fileSystem;
  late TizenOperatingSystemUtils osUtils;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    osUtils = TizenOperatingSystemUtils(
      fileSystem: fileSystem,
      logger: BufferLogger.test(),
      platform: FakePlatform(operatingSystem: 'windows'),
      processManager: FakeProcessManager.empty(),
    );
  });

  File createZipFile(String entryName) {
    const content = 'hello, world!';
    final archive = Archive()..addFile(ArchiveFile(entryName, content.length, content.codeUnits));
    return fileSystem.file('archive.zip')..writeAsBytesSync(ZipEncoder().encode(archive)!);
  }

  testWithoutContext('Windows extracts archive entries into the target directory', () {
    final File zipFile = createZipFile('lib/libfoo.so');
    final Directory targetDirectory = fileSystem.directory('output')..createSync();

    osUtils.unzip(zipFile, targetDirectory);

    expect(
      targetDirectory.childDirectory('lib').childFile('libfoo.so').readAsStringSync(),
      'hello, world!',
    );
  });

  testWithoutContext('Windows rejects archive entries outside the target directory', () {
    final File zipFile = createZipFile('../../../Target File.txt');
    final Directory targetDirectory = fileSystem.directory('output')..createSync();

    expect(
      () => osUtils.unzip(zipFile, targetDirectory),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('Tried to extract the file '),
        ),
      ),
    );
  });

  testWithoutContext(
    'Windows rejects archive entries that escape into a sibling directory with a name prefix',
    () {
      final File zipFile = createZipFile('../windows-x64-profile/poc_marker.txt');
      final Directory targetDirectory = fileSystem.directory('cache/windows-x64')
        ..createSync(recursive: true);

      expect(
        () => osUtils.unzip(zipFile, targetDirectory),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('Tried to extract the file '),
          ),
        ),
      );
      expect(fileSystem.file('cache/windows-x64-profile/poc_marker.txt').existsSync(), isFalse);
    },
  );
}
