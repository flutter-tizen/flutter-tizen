// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

String getEmCliPath() {
  return TizenSdk.instance?.emCli?.path;
}

String getSdbPath() {
  return TizenSdk.instance?.sdb?.path;
}

String getTizenCliPath() {
  return TizenSdk.instance?.tizenCli?.path;
}

String getDotnetCliPath() {
  return globals.os.which('dotnet')?.path;
}

class TizenSdk {
  TizenSdk._(this.directory);

  /// See: [AndroidSdk.locateAndroidSdk] in `android_sdk.dart`
  factory TizenSdk.locateSdk() {
    Directory tizenHomeDir;
    final Map<String, String> environment = globals.platform.environment;
    final File sdb = globals.os.which('sdb');
    if (environment.containsKey('TIZEN_SDK')) {
      tizenHomeDir = globals.fs.directory(environment['TIZEN_SDK']);
    } else if (sdb != null && sdb.parent.basename == 'tools') {
      tizenHomeDir = sdb.parent.parent;
    } else if (globals.fsUtils.homeDirPath != null) {
      tizenHomeDir = globals.fs
          .directory(globals.fsUtils.homeDirPath)
          .childDirectory('tizen-studio');
    }
    if (tizenHomeDir == null || !tizenHomeDir.existsSync()) {
      return null;
    }
    return TizenSdk._(tizenHomeDir);
  }

  static TizenSdk instance = TizenSdk.locateSdk();

  final Directory directory;

  Directory get platformsDirectory => directory.childDirectory('platforms');

  Directory get toolsDirectory => directory.childDirectory('tools');

  File get emCli => toolsDirectory
      .childDirectory('emulator')
      .childDirectory('bin')
      .childFile('em-cli');

  File get sdb => toolsDirectory.childFile('sdb');

  File get tizenCli => toolsDirectory
      .childDirectory('ide')
      .childDirectory('bin')
      .childFile('tizen');

  String get defaultTargetPlatform => '5.5';

  String get defaultNativeCompiler => 'llvm-10.0';

  String get defaultGccVersion => '9.2';

  String getFlutterRootstrap(String arch) {
    // TODO(swift-kim): Always use wearable 5.5 rootstrap for plugin builds?
    final String rootstrapName =
        'wearable-5.5-${arch == 'x86' ? 'emulator' : 'device'}.flutter';

    // Tizen SBI creates a list of rootstraps from this directory.
    final Directory pluginsDir = toolsDirectory
        .childDirectory('smart-build-interface')
        .childDirectory('plugins');
    final Link rootstrapLink = pluginsDir.childLink('$rootstrapName.xml');
    if (rootstrapLink.existsSync()) {
      rootstrapLink.deleteSync(recursive: true);
    }
    final File rootstrapTarget = globals.fs
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('rootstraps')
        .childFile('$rootstrapName.xml');
    rootstrapLink.createSync(rootstrapTarget.path, recursive: true);

    return rootstrapName;
  }
}
