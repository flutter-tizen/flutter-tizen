// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/attach.dart';

class TizenAttachCommand extends AttachCommand {
  TizenAttachCommand({super.verboseHelp, super.hotRunnerFactory});

  @override
  String get description => '${super.description}\n\n'
      'For attaching to Tizen devices, the observatory URL must be provided, e.g.\n'
      r'`$ flutter attach --debug-url=http://127.0.0.1:43000/Swm0bjIe0ks=/`';
}
