// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../tizen_sdk.dart';

extension PathUtils on String {
  /// On non-Windows, returns the path string unchanged.
  ///
  /// On Windows, converts Windows-style path (e.g. 'C:\x\y') into POSIX path
  /// ('/c/x/y') and returns.
  String toPosixPath() {
    String path = this;
    if (Platform.isWindows) {
      path = path.replaceAll(r'\', '/');
      if (path.startsWith(':', 1)) {
        path = '/${path[0].toLowerCase()}${path.substring(2)}';
      }
    }
    return path;
  }
}

/// On non-Windows, returns the PATH environment variable.
///
/// On Windows, appends the msys2 executables directory to PATH and returns.
String getDefaultPathVariable() {
  final Map<String, String> variables = globals.platform.environment;
  String path = variables.containsKey('PATH') ? variables['PATH'] : '';
  if (Platform.isWindows) {
    assert(tizenSdk != null);
    final String msysUsrBin = tizenSdk.toolsDirectory
        .childDirectory('msys2')
        .childDirectory('usr')
        .childDirectory('bin')
        .path;
    path += ';$msysUsrBin';
  }
  return path;
}

/// See: [CachedArtifacts._getEngineArtifactsPath]
Directory getEngineArtifactsDirectory(String arch, BuildMode mode) {
  assert(mode != null, 'Need to specify a build mode.');
  return globals.cache
      .getArtifactDirectory('engine')
      .childDirectory('tizen-$arch-${mode.name}');
}

/// Removes the "lib" prefix and file extension from [name] and returns.
String getLibNameForFileName(String name) {
  if (name.startsWith('lib')) {
    name = name.substring(3);
  }
  if (name.lastIndexOf('.') > 0) {
    name = name.substring(0, name.lastIndexOf('.'));
  }
  return name;
}
