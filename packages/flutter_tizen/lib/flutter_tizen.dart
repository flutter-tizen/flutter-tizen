// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

/// Whether the current profile is TV profile.
bool get isTvProfile {
  return Platform.environment['ELM_PROFILE'] == 'tv';
}

// TODO(jsuya): With Tizen Studio 5.5, the 'Common' profile is now called the 'Tizen' profile.
// https://developer.tizen.org/blog/announcing-tizen-studio-5.5-release
/// Whether the current profile is Tizen profile.
bool get isTizenProfile {
  return Platform.environment['ELM_PROFILE'] == 'common';
}

/// Whether the current operating system is Tizen.
bool get isTizen {
  return Platform.environment.containsKey('TIZEN_API_VERSION');
}

/// The api version of the currently running app.
///
/// If the operating system is not Tizen, return "none".
String get apiVersion {
  return Platform.environment['TIZEN_API_VERSION'] ?? 'none';
}
