// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tizen/tizen_flutter_version.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../src/common.dart';
import '../src/context.dart';
import '../src/test_flutter_command_runner.dart';

void main() {
  setUpAll(() {
    Cache.flutterRoot = 'flutter';
  });

  testUsingContext('Detects flutter-tizen tag and revision.', () async {
    final TizenFlutterVersion tizenFlutterVersion = TizenFlutterVersion(
      fs: globals.fs,
      flutterRoot: Cache.flutterRoot!,
    );

    expect(tizenFlutterVersion.flutterTizenTag, isEmpty);
    expect(tizenFlutterVersion.flutterTizenLatestRevision, isNotEmpty);
  }, overrides: <Type, Generator>{});
}
