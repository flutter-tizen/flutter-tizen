// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

const String kConfigNameAttach = 'flutter-tizen: Attach';

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

void updateLaunchJsonFile(FlutterProject project, Uri observatoryUri) {
  if (project.directory.basename == 'example') {
    final FlutterProject parentProject =
        FlutterProject.fromDirectory(project.directory.parent);
    if (parentProject.pubspecFile.existsSync()) {
      updateLaunchJsonFile(parentProject, observatoryUri);
    }
  }

  final Directory vscodeDir = project.directory.childDirectory('.vscode')
    ..createSync(recursive: true);
  final File launchJsonFile = vscodeDir.childFile('launch.json');
  String jsonString = '';
  if (launchJsonFile.existsSync()) {
    jsonString = _processJson(launchJsonFile.readAsStringSync());
  }

  Map<dynamic, dynamic> decoded = <dynamic, dynamic>{};
  if (jsonString.isNotEmpty) {
    try {
      decoded = jsonDecode(jsonString) as Map<dynamic, dynamic>;
    } on FormatException catch (error) {
      globals.printError('Failed to parse ${launchJsonFile.path}:\n$error');
      return;
    }
  }
  decoded['version'] ??= '0.2.0';
  decoded['configurations'] ??= <dynamic>[];

  final List<dynamic> configs = decoded['configurations'] as List<dynamic>;
  if (!configs.any((dynamic conf) => conf['name'] == kConfigNameAttach)) {
    configs.add(<String, String>{
      'name': kConfigNameAttach,
      'request': 'attach',
      'type': 'dart',
      'deviceId': 'flutter-tester',
    });
  }
  for (final dynamic config in configs) {
    if (config['name'] != kConfigNameAttach) {
      continue;
    }
    config['cwd'] = r'${workspaceFolder}';
    if (project.hasExampleApp) {
      config['cwd'] += '/example';
    }
    config['observatoryUri'] = observatoryUri.toString();
  }

  const JsonEncoder encoder = JsonEncoder.withIndent('    ');
  launchJsonFile.writeAsStringSync(encoder.convert(decoded));
}
