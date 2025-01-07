// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

/// Whether the current operating system is Tizen.
bool get isTizen {
  return Platform.environment.containsKey('TIZEN_API_VERSION');
}

/// The api version of the currently running app.
///
/// If the operating system is not Tizen, return "none".
String get apiVersion {
  return Platform.environment['TIZEN_API_VERSION'] ?? "none";
}
