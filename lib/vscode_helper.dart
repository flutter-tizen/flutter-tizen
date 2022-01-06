// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/project.dart';

const String kConfigNameAttach = 'flutter-tizen: Attach';
const String kConfigNameGdb = 'flutter-tizen: gdb';

FlutterProject? _findParentProject(FlutterProject project) {
  if (project.directory.basename == 'example') {
    final FlutterProject parent =
        FlutterProject.fromDirectory(project.directory.parent);
    if (parent.pubspecFile.existsSync()) {
      return parent;
    }
  }
  return null;
}

String _processJson(String jsonString) {
  // The extended JSON format used by launch.json files allows comments and
  // trailing commas. Remove them to prevent decoding errors.
  final RegExp comments =
      RegExp(r'(?<![:"/])(/\*([^*]|[\r\n]|(\*+([^*/]|[\r\n])))*\*+/|//.*\n?)');
  final RegExp trailingCommas = RegExp(r',(?=\s*?[\}\]])');
  return jsonString
      .replaceAll(comments, '')
      .replaceAll(trailingCommas, '')
      .trim();
}

Map<Object?, Object?> _parseLaunchJson(File launchJsonFile) {
  String jsonString = '';
  if (launchJsonFile.existsSync()) {
    jsonString = _processJson(launchJsonFile.readAsStringSync());
  }

  Map<Object?, Object?> decoded = <Object?, Object?>{};
  if (jsonString.isNotEmpty) {
    try {
      decoded = jsonDecode(jsonString) as Map<Object?, Object?>;
    } on FormatException catch (error) {
      // Unexpected failure. It is safe not to overwrite the file.
      throwToolExit('Failed to parse ${launchJsonFile.path}:\n$error');
    }
  }
  decoded['version'] ??= '0.2.0';
  decoded['configurations'] ??= <Object?>[];

  return decoded;
}

void updateLaunchJsonWithObservatoryInfo(
  FlutterProject project,
  Uri observatoryUri,
) {
  final FlutterProject? parentProject = _findParentProject(project);
  if (parentProject != null) {
    updateLaunchJsonWithObservatoryInfo(parentProject, observatoryUri);
  }

  final File launchJsonFile =
      project.directory.childDirectory('.vscode').childFile('launch.json');
  final Map<Object?, Object?> decoded = _parseLaunchJson(launchJsonFile);

  final List<Object?> configs = decoded['configurations']! as List<Object?>;
  if (!configs.any((Object? config) =>
      config is Map && config['name'] == kConfigNameAttach)) {
    configs.add(<String, String>{
      'name': kConfigNameAttach,
      'request': 'attach',
      'type': 'dart',
      'deviceId': 'flutter-tester',
    });
  }
  for (final Object? config in configs) {
    if (config is! Map || config['name'] != kConfigNameAttach) {
      continue;
    }
    config['cwd'] = project.hasExampleApp
        ? r'${workspaceFolder}/example'
        : r'${workspaceFolder}';
    config['observatoryUri'] = observatoryUri.toString();
  }

  const JsonEncoder encoder = JsonEncoder.withIndent('    ');
  launchJsonFile
    ..createSync(recursive: true)
    ..writeAsStringSync(encoder.convert(decoded));
}

void updateLaunchJsonWithRemoteDebuggingInfo(
  FlutterProject project, {
  required File program,
  required String gdbPath,
  required int debugPort,
}) {
  final FlutterProject? parentProject = _findParentProject(project);
  if (parentProject != null) {
    updateLaunchJsonWithRemoteDebuggingInfo(
      parentProject,
      program: program,
      gdbPath: gdbPath,
      debugPort: debugPort,
    );
  }

  final File launchJsonFile =
      project.directory.childDirectory('.vscode').childFile('launch.json');
  final Map<Object?, Object?> decoded = _parseLaunchJson(launchJsonFile);

  final List<Object?> configs = decoded['configurations']! as List<Object?>;
  if (!configs.any(
      (Object? config) => config is Map && config['name'] == kConfigNameGdb)) {
    configs.add(<String, Object>{
      'name': kConfigNameGdb,
      'request': 'launch',
      'type': 'cppdbg',
      'externalConsole': false,
      'MIMode': 'gdb',
      'sourceFileMap': <String, Object>{},
      'symbolLoadInfo': <String, Object>{
        'loadAll': false,
        'exceptionList': 'libflutter*.so'
      },
    });
  }
  for (final Object? config in configs) {
    if (config is! Map || config['name'] != kConfigNameGdb) {
      continue;
    }
    config['cwd'] = project.hasExampleApp
        ? r'${workspaceFolder}/example'
        : r'${workspaceFolder}';
    config['program'] = program.path
        .replaceFirst(project.directory.path, r'${workspaceFolder}');
    config['miDebuggerPath'] = gdbPath;
    config['miDebuggerServerAddress'] = ':$debugPort';
  }

  const JsonEncoder encoder = JsonEncoder.withIndent('    ');
  launchJsonFile
    ..createSync(recursive: true)
    ..writeAsStringSync(encoder.convert(decoded));
}
