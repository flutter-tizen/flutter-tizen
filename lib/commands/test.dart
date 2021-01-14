// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/test.dart';

import '../tizen_plugins.dart';

class TizenTestCommand extends TestCommand with TizenExtension {
  TizenTestCommand({bool verboseHelp = false})
      : super(verboseHelp: verboseHelp);
}
