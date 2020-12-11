// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

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

  Directory get sdkDataDirectory {
    final File sdkInfo = directory.childFile('sdk.info');
    if (sdkInfo.existsSync()) {
      final Map<String, String> info = parseIniLines(sdkInfo.readAsLinesSync());
      if (info.containsKey('TIZEN_SDK_DATA_PATH')) {
        return globals.fs.directory(info['TIZEN_SDK_DATA_PATH']);
      }
    }
    return null;
  }

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

Map<String, String> parseIniLines(List<String> contents) {
  final Map<String, String> results = <String, String>{};

  final Iterable<List<String>> properties = contents
      .map<String>((String l) => l.trim())
      // Strip blank lines/comments
      .where((String l) => l != '' && !l.startsWith('#'))
      // Discard anything that isn't simple name=value
      .where((String l) => l.contains('='))
      // Split into name/value
      // The parser method assumes no equal signs(=) in 'name',
      // so the method splits the string at the first equal sign.
      .map<List<String>>((String l) {
    final int splitPos = l.indexOf('=');
    return <String>[l.substring(0, splitPos), l.substring(splitPos + 1)];
  });

  for (final List<String> property in properties) {
    results[property[0].trim()] = property[1].trim();
  }

  return results;
}
