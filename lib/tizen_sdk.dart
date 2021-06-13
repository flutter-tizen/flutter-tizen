// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_emulator.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:meta/meta.dart';

import 'tizen_tpk.dart';

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
    if (!sdkInfo.existsSync()) {
      return null;
    }
    // ignore: invalid_use_of_visible_for_testing_member
    final Map<String, String> info = parseIniLines(sdkInfo.readAsLinesSync());
    if (info.containsKey('TIZEN_SDK_DATA_PATH')) {
      return globals.fs.directory(info['TIZEN_SDK_DATA_PATH']);
    }
    return null;
  }

  String get sdkVersion {
    final File versionFile = directory.childFile('sdk.version');
    if (!versionFile.existsSync()) {
      return null;
    }
    final Map<String, String> info =
        // ignore: invalid_use_of_visible_for_testing_member
        parseIniLines(versionFile.readAsLinesSync());
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

  File get securityProfilesFile =>
      sdkDataDirectory.childDirectory('profile').childFile('profiles.xml');

  SecurityProfiles get securityProfiles =>
      SecurityProfiles.parseFromXml(securityProfilesFile);

  String get defaultNativeCompiler => 'llvm-10.0';

  String get defaultGccVersion => '9.2';

  Rootstrap getFlutterRootstrap({
    String profile = 'common-4.0',
    @required String arch,
  }) {
    // Defaults to wearable if the profile name is common.
    profile = profile.replaceFirst('common', 'wearable');

    String id;
    if (arch == 'arm64') {
      // The arm64 build is only supported by the iot-headed-6.0 profile.
      profile = 'iot-headed-6.0';
      id = '$profile-device64.core';
    } else {
      id = '$profile-${arch == 'x86' ? 'emulator' : 'device'}.core';
    }

    // Tizen SBI reads rootstrap definitions from this directory.
    final Directory pluginsDir = toolsDirectory
        .childDirectory('smart-build-interface')
        .childDirectory('plugins');

    File manifestFile = pluginsDir.childFile('$id.xml');
    if (!manifestFile.existsSync()) {
      final String profileUpperCase =
          profile.toUpperCase().replaceAll('HEADED', 'Headed');
      throwToolExit(
        'The rootstrap definition for the $profile profile could not be found.\n'
        'Try with another profile or run this command to install missing packages:\n'
        '${packageManagerCli.path} install $profileUpperCase-NativeAppDevelopment-CLI',
      );
    }

    // Create a custom rootstrap to force the use of GCC 9.2 for Tizen 4.0/5.5.
    if (arch != 'arm64' && !profile.endsWith('6.0')) {
      id = '$profile-$arch.flutter';

      manifestFile = globals.fs
          .directory(Cache.flutterRoot)
          .parent
          .childDirectory('rootstraps')
          .childFile('$id.xml');
      if (!manifestFile.existsSync()) {
        throwToolExit(
          'The $profile profile is not currently supported by flutter-tizen.\n'
          'Try with another profile or file an issue in https://github.com/flutter-tizen/flutter-tizen/issues.',
        );
      }

      final File manifestCopy = pluginsDir.childFile('$id.xml');
      if (manifestCopy.existsSync()) {
        manifestCopy.deleteSync(recursive: true);
      }
      manifestFile.copySync(manifestCopy.path);
    }

    return Rootstrap(id, manifestFile);
  }
}

/// Tizen rootstrap definition.
///
/// The rootstrap (or sysroot), which is downloaded as part of Tizen native SDK,
/// contains a set of headers and libraries required for cross building Tizen
/// native apps and libraries.
class Rootstrap {
  const Rootstrap(this.id, this.manifestFile);

  final String id;
  final File manifestFile;
}
