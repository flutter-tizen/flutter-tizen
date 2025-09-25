// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:archive/archive.dart';
import 'package:file/file.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:process/process.dart';

/// Used for overriding [OperatingSystemUtils.unzip].
class TizenOperatingSystemUtils implements OperatingSystemUtils {
  TizenOperatingSystemUtils({
    required FileSystem fileSystem,
    required Logger logger,
    required Platform platform,
    required ProcessManager processManager,
  })  : _osUtils = OperatingSystemUtils(
          fileSystem: fileSystem,
          logger: logger,
          platform: platform,
          processManager: processManager,
        ),
        _platform = platform;

  final OperatingSystemUtils _osUtils;
  final Platform _platform;

  @override
  void chmod(FileSystemEntity entity, String mode) => _osUtils.chmod(entity, mode);

  @override
  Future<int> findFreePort({bool ipv6 = false}) => _osUtils.findFreePort(ipv6: ipv6);

  @override
  int? getDirectorySize(Directory directory) => _osUtils.getDirectorySize(directory);

  @override
  Stream<List<int>> gzipLevel1Stream(Stream<List<int>> stream) => _osUtils.gzipLevel1Stream(stream);

  @override
  HostPlatform get hostPlatform => _osUtils.hostPlatform;

  @override
  void makeExecutable(File file) => _osUtils.makeExecutable(file);

  @override
  File makePipe(String path) => _osUtils.makePipe(path);

  @override
  String get name => _osUtils.name;

  @override
  String get pathVarSeparator => _osUtils.pathVarSeparator;

  @override
  void unpack(File gzippedTarFile, Directory targetDirectory) =>
      _osUtils.unpack(gzippedTarFile, targetDirectory);

  /// Source: [unzip] in `os.dart`
  @override
  void unzip(File file, Directory targetDirectory) {
    // Unzipping a native TPK using _osUtils.unzip() fails on Windows.
    // Issue: https://github.com/flutter-tizen/flutter-tizen/issues/198
    if (!_platform.isWindows) {
      return _osUtils.unzip(file, targetDirectory);
    }
    final Archive archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
    for (final ArchiveFile archiveFile in archive.files) {
      // The archive package doesn't correctly set isFile.
      if (archiveFile.name.endsWith('/')) {
        continue;
      }
      final File destFile = targetDirectory.childFile(archiveFile.name);
      if (!destFile.parent.existsSync()) {
        destFile.parent.createSync(recursive: true);
      }
      destFile.writeAsBytesSync(archiveFile.content as List<int>);
    }
  }

  @override
  File? which(String execName) => _osUtils.which(execName);

  @override
  List<File> whichAll(String execName) => _osUtils.whichAll(execName);
}
