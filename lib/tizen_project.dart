// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_tools/src/base/file_system.dart';
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

  File get manifestFile => editableDirectory.childFile('tizen-manifest.xml');

  @override
  bool existsSync() => projectFile.existsSync() && manifestFile.existsSync();

  String get apiVersion => TizenManifest.parseFromXml(manifestFile).apiVersion;

  String get outputTpkName {
    final TizenManifest manifest = TizenManifest.parseFromXml(manifestFile);
    return '${manifest.packageId}-${manifest.version}.tpk';
  }

  Future<void> ensureReadyForPlatformSpecificTooling() async {}
}
