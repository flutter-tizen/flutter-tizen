// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/attach.dart';

class TizenAttachCommand extends AttachCommand {
  TizenAttachCommand({
    required super.buildSystem,
    required super.buildTargets,
    required super.toolContext,
    required super.xcode,
    super.hotRunnerFactory,
    super.verboseHelp,
  });

  @override
  String get description => '${super.description}\n\n'
      'For attaching to Tizen devices, the VM Service URL must be provided, e.g.\n'
      r'`$ flutter-tizen attach --debug-url=http://127.0.0.1:43000/Swm0bjIe0ks=/`';
}
