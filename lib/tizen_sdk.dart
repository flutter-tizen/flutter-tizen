// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tizen/tizen_tpk.dart';
import 'package:flutter_tools/src/android/android_emulator.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:meta/meta.dart';

TizenSdk get tizenSdk => context.get<TizenSdk>();

File get dotnetCli => globals.os.which('dotnet');

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
    } else if (globals.platform.isLinux || globals.platform.isMacOS) {
      if (globals.fsUtils.homeDirPath != null) {
        tizenHomeDir = globals.fs
            .directory(globals.fsUtils.homeDirPath)
            .childDirectory('tizen-studio');
      }
    } else if (globals.platform.isWindows) {
      if (environment.containsKey('SystemDrive')) {
        tizenHomeDir = globals.fs
            .directory(environment['SystemDrive'])
            .childDirectory('tizen-studio');
      }
    }
    if (tizenHomeDir == null || !tizenHomeDir.existsSync()) {
      return null;
    }
    return TizenSdk._(tizenHomeDir);
  }

  final Directory directory;

  Directory get platformsDirectory => directory.childDirectory('platforms');

  Directory get toolsDirectory => directory.childDirectory('tools');

  Directory get sdkDataDirectory {
    final File sdkInfo = directory.childFile('sdk.info');
    final Map<String, String> info = parseIniFile(sdkInfo);
    if (info.containsKey('TIZEN_SDK_DATA_PATH')) {
      return globals.fs.directory(info['TIZEN_SDK_DATA_PATH']);
    }
    return null;
  }

  String get sdkVersion {
    final File versionFile = directory.childFile('sdk.version');
    final Map<String, String> info = parseIniFile(versionFile);
    if (info.containsKey('TIZEN_SDK_VERSION')) {
      String version = info['TIZEN_SDK_VERSION'];
      final List<String> segments = version.split('.');
      if (segments.length > 2) {
        version = segments.sublist(0, 2).join('.');
      }
      return version;
    }
    return null;
  }

  File get sdb =>
      toolsDirectory.childFile(globals.platform.isWindows ? 'sdb.exe' : 'sdb');

  File get tizenCli => toolsDirectory
      .childDirectory('ide')
      .childDirectory('bin')
      .childFile(globals.platform.isWindows ? 'tizen.bat' : 'tizen');

  File get emCli => toolsDirectory
      .childDirectory('emulator')
      .childDirectory('bin')
      .childFile(globals.platform.isWindows ? 'em-cli.bat' : 'em-cli');

  File get packageManagerCli => directory
      .childDirectory('package-manager')
      .childFile(globals.platform.isWindows
          ? 'package-manager-cli.exe'
          : 'package-manager-cli.bin');

  File get certificateProfilesFile =>
      sdkDataDirectory.childDirectory('profile').childFile('profiles.xml');

  CertificateProfiles get certificateProfiles =>
      CertificateProfiles.parseFromXml(certificateProfilesFile);

  String get defaultTargetPlatform => '4.0';

  String get defaultNativeCompiler => 'llvm-10.0';

  String get defaultGccVersion => '9.2';

  String getFlutterRootstrap({
    String profile,
    @required String arch,
  }) {
    final String type = arch == 'x86' ? 'emulator' : 'device';
    final String rootstrapName = profile == null
        ? 'wearable-$defaultTargetPlatform-$type.flutter'
        : '${profile.replaceFirst('common', 'wearable')}-$type.flutter';

    final File rootstrapTarget = globals.fs
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('rootstraps')
        .childFile('$rootstrapName.xml');
    if (!rootstrapTarget.existsSync()) {
      throwToolExit(
        'File not found: ${rootstrapTarget.absolute.path}\n'
        'Make sure your tizen-manifest.xml contains correct information for build.',
      );
    }

    // Tizen SBI creates a list of rootstraps from this directory.
    final Directory pluginsDir = toolsDirectory
        .childDirectory('smart-build-interface')
        .childDirectory('plugins');
    final Link rootstrapLink = pluginsDir.childLink('$rootstrapName.xml');
    if (rootstrapLink.existsSync()) {
      rootstrapLink.deleteSync(recursive: true);
    }
    rootstrapLink.createSync(rootstrapTarget.path, recursive: true);

    return rootstrapName;
  }
}

/// Source: [parseIniLines] in `android_emulator.dart`
Map<String, String> parseIniFile(File file) {
  if (!file.existsSync()) {
    return <String, String>{};
  }
  final List<String> contents = file.readAsLinesSync();
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
