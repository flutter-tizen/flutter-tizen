// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

const String kConfigNameAttach = 'Attach (flutter-tizen)';

final RegExp _commentFormat =
    RegExp(r'(:?)(/\*([^*]|[\r\n]|(\*+([^*/]|[\r\n])))*\*+/|//.*\n?)');

String _removeComments(String jsonString) {
  return jsonString.replaceAllMapped(
    _commentFormat,
    (Match match) {
      // "aaa://bbb" contains "//" but is not a comment.
      return match.group(1) == ':' ? match.group(0) : '';
    },
  ).trim();
}

void updateLaunchJsonFile(FlutterProject project, Uri observatoryUri) {
  Directory vscodeDir;
  String cwd = r'${workspaceFolder}';
  if (project.directory.basename == 'example') {
    final FlutterProject parentProject =
        FlutterProject.fromDirectory(project.directory.parent);
    if (parentProject.isPlugin || parentProject.isModule) {
      vscodeDir = parentProject.directory.childDirectory('.vscode')
        ..createSync(recursive: true);
      cwd += '/example';
    }
  }
  vscodeDir ??= project.directory.childDirectory('.vscode')
    ..createSync(recursive: true);

  final File launchJsonFile = vscodeDir.childFile('launch.json');
  String jsonString = '';
  if (launchJsonFile.existsSync()) {
    // Comments are allowed in launch.json file. Remove them to prevent
    // decoding errors.
    jsonString = _removeComments(launchJsonFile.readAsStringSync());
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
    config['cwd'] = cwd;
    config['observatoryUri'] = observatoryUri.toString();
  }

  const JsonEncoder encoder = JsonEncoder.withIndent('    ');
  launchJsonFile.writeAsStringSync(encoder.convert(decoded));
}
