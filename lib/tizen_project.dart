// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

import 'tizen_plugins.dart';
import 'tizen_tpk.dart';

/// Source: [WindowsProject] in `project.dart`
class TizenProject extends FlutterProjectPlatform {
  TizenProject.fromFlutter(this.parent);

  final FlutterProject parent;

  @override
  String get pluginConfigKey => TizenPlugin.kConfigKey;

  Directory get editableDirectory => parent.directory.childDirectory('tizen');

  /// The directory in the project that is managed by Flutter. As much as
  /// possible, files that are edited by Flutter tooling after initial project
  /// creation should live here.
  Directory get managedDirectory => editableDirectory.childDirectory('flutter');

  /// The subdirectory of [managedDirectory] that contains files that are
  /// generated on the fly. All generated files that are not intended to be
  /// checked in should live here.
  Directory get ephemeralDirectory =>
      managedDirectory.childDirectory('ephemeral');

  bool get isDotnet =>
      editableDirectory.childFile('Runner.csproj').existsSync();

  File get projectFile => editableDirectory
      .childFile(isDotnet ? 'Runner.csproj' : 'project_def.prop');

  @override
  bool existsSync() =>
      editableDirectory.existsSync() && projectFile.existsSync();

  File get manifestFile => editableDirectory.childFile('tizen-manifest.xml');

  String get outputTpkName {
    final TizenManifest manifest = TizenManifest.parseFromXml(manifestFile);
    return '${manifest.packageId}-${manifest.version}.tpk';
  }

  Future<void> ensureReadyForPlatformSpecificTooling() async {}
}

/// Used for parsing native plugin's `project_def.prop`.
class TizenNativeProject {
  TizenNativeProject(this.path);

  final String path;

  Directory get directory => globals.fs.directory(path).absolute;

  File get projectFile => directory.childFile('project_def.prop');

  bool get isValid => projectFile.existsSync();

  final RegExp _propertyFormat = RegExp(r'(\S+)\s*\+?=(.*)');

  Future<Map<String, String>> get properties async {
    final Map<String, String> map = <String, String>{};
    if (!isValid) {
      return map;
    }

    final List<String> lines = await projectFile.readAsLines();
    for (final String line in lines) {
      final Match match = _propertyFormat.firstMatch(line);
      if (match == null) {
        continue;
      }
      final String key = match.group(1);
      final String value = match.group(2).trim();
      map[key] = value;
    }
    return map;
  }

  Future<List<String>> getPropertyAsAbsolutePaths(String key) async {
    final Map<String, String> propertyMap = await properties;
    if (!propertyMap.containsKey(key)) {
      return <String>[];
    }

    final List<String> paths = <String>[];
    for (final String element in propertyMap[key].split(' ')) {
      if (globals.fs.path.isAbsolute(element)) {
        paths.add(element);
      } else {
        paths.add(globals.fs.path
            .normalize(globals.fs.path.join(directory.path, element)));
      }
    }
    return paths;
  }
}
