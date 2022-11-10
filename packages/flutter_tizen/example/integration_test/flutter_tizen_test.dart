// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tizen/flutter_tizen.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('detects the current platform', (WidgetTester tester) async {
    expect(Platform.isLinux, isTrue);
    expect(isTizen, isTrue);
  });
}
