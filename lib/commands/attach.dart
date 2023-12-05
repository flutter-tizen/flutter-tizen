// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/attach.dart';

class TizenAttachCommand extends AttachCommand {
  TizenAttachCommand({
    super.verboseHelp,
    super.hotRunnerFactory,
    required super.stdio,
    required super.logger,
    required super.terminal,
    required super.signals,
    required super.platform,
    required super.processInfo,
    required super.fileSystem,
  });

  @override
  String get description => '${super.description}\n\n'
      'For attaching to Tizen devices, the VM Service URL must be provided, e.g.\n'
      r'`$ flutter attach --debug-url=http://127.0.0.1:43000/Swm0bjIe0ks=/`';
}
