// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:meta/meta.dart';
import 'package:process/process.dart';
import 'package:xml/xml.dart';

TizenSdk? get tizenSdk => context.get<TizenSdk>();

File? get dotnetCli => globals.os.which('dotnet');

class TizenSdk {
  TizenSdk(
    this.directory, {
    required Logger logger,
    required Platform platform,
    required ProcessManager processManager,
  })  : _logger = logger,
        _platform = platform,
        _processUtils = ProcessUtils(logger: logger, processManager: processManager);

  /// See: [AndroidSdk.locateAndroidSdk] in `android_sdk.dart`
  static TizenSdk? locateSdk() {
    Directory? tizenHomeDir;
    final Map<String, String> environment = globals.platform.environment;
    final File? sdb = globals.os.which('sdb');
    if (environment.containsKey('TIZEN_SDK')) {
      tizenHomeDir = globals.fs.directory(environment['TIZEN_SDK']);
    } else if (sdb != null && sdb.parent.basename == 'tools') {
      tizenHomeDir = sdb.parent.parent;
    } else if (globals.platform.isLinux || globals.platform.isMacOS) {
      if (globals.fsUtils.homeDirPath != null) {
        tizenHomeDir =
            globals.fs.directory(globals.fsUtils.homeDirPath).childDirectory('tizen-studio');
      }
    } else if (globals.platform.isWindows) {
      if (environment.containsKey('SystemDrive')) {
        tizenHomeDir =
            globals.fs.directory(environment['SystemDrive']).childDirectory('tizen-studio');
      }
    }
    if (tizenHomeDir == null || !tizenHomeDir.existsSync()) {
      return null;
    }
    return TizenSdk(
      tizenHomeDir,
      logger: globals.logger,
      platform: globals.platform,
      processManager: globals.processManager,
    );
  }

  final Directory directory;

  final Logger _logger;
  final Platform _platform;
  final ProcessUtils _processUtils;

  Directory get platformsDirectory => directory.childDirectory('platforms');

  Directory get toolsDirectory => directory.childDirectory('tools');

  Directory get sdkDataDirectory {
    final File sdkInfo = directory.childFile('sdk.info');
    if (!sdkInfo.existsSync()) {
      throwToolExit(
          'The sdk.info file could not be found. Tizen Studio is out of date or corrupted.');
    }
    final Map<String, String> info = parseIniFile(sdkInfo);
    if (info.containsKey('TIZEN_SDK_DATA_PATH')) {
      final Directory dataDir = directory.fileSystem.directory(info['TIZEN_SDK_DATA_PATH']);
      if (dataDir.existsSync()) {
        return dataDir;
      }
    }
    throwToolExit(
        'The SDK data directory could not be found. Tizen Studio is out of date or corrupted.');
  }

  /// The SDK version number in the "x.y[.z]" format, or null if not found.
  String? get sdkVersion {
    final File versionFile = directory.childFile('sdk.version');
    if (!versionFile.existsSync()) {
      return null;
    }
    return parseIniFile(versionFile)['TIZEN_SDK_VERSION'];
  }

  File get sdb => toolsDirectory.childFile(_platform.isWindows ? 'sdb.exe' : 'sdb');

  File get tizenCli => toolsDirectory
      .childDirectory('ide')
      .childDirectory('bin')
      .childFile(_platform.isWindows ? 'tizen.bat' : 'tizen');

  File get tzCli =>
      toolsDirectory.childDirectory('tizen-core').childFile(_platform.isWindows ? 'tz.exe' : 'tz');

  File get emCli => toolsDirectory
      .childDirectory('emulator')
      .childDirectory('bin')
      .childFile(_platform.isWindows ? 'em-cli.bat' : 'em-cli');

  File get packageManagerCli => directory
      .childDirectory('package-manager')
      .childFile(_platform.isWindows ? 'package-manager-cli.exe' : 'package-manager-cli.bin');

  SecurityProfiles? get securityProfiles {
    final File manifest = sdkDataDirectory.childDirectory('profile').childFile('profiles.xml');
    return SecurityProfiles.parseFromXml(manifest);
  }

  final String defaultNativeCompiler = 'llvm-10.0';

  final String defaultGccVersion = '9.2';

  /// On non-Windows, returns the PATH environment variable.
  ///
  /// On Windows, prepends the msys2 /usr/bin directory to PATH and returns.
  @visibleForTesting
  String getPathVariable() {
    String path = _platform.environment['PATH'] ?? '';
    if (_platform.isWindows) {
      final Directory msysUsrBin =
          toolsDirectory.childDirectory('msys2').childDirectory('usr').childDirectory('bin');
      path = '${msysUsrBin.path};$path';
    }
    return path;
  }

  Future<RunResult> buildApp(
    String workingDirectory, {
    Map<String, Object> build = const <String, Object>{},
    Map<String, Object> method = const <String, Object>{},
    String? output,
    Map<String, Object> package = const <String, Object>{},
    String? sign,
    Map<String, String> environment = const <String, String>{},
  }) {
    String stringify(Object argument) {
      if (argument is String) {
        return '"${argument.replaceAll('"', r'\"')}"';
      } else if (argument is List<Object>) {
        return argument.map<String>(stringify).toList().toString();
      } else if (argument is Map<String, Object>) {
        for (final MapEntry<String, Object> entry in argument.entries) {
          argument[entry.key] = stringify(entry.value);
        }
        return argument.toString();
      } else {
        throwToolExit('Unsupported type: ${argument.runtimeType}');
      }
    }

    String trim(String string) {
      return string.substring(1, string.length - 1);
    }

    return _processUtils.run(
      <String>[
        tizenCli.path,
        'build-app',
        if (build.isNotEmpty) ...<String>['-b', trim(stringify(build))],
        if (method.isNotEmpty) ...<String>['-m', trim(stringify(method))],
        if (output != null) ...<String>['-o', output],
        if (package.isNotEmpty) ...<String>['-p', trim(stringify(package))],
        if (sign != null) ...<String>['-s', sign],
        '--',
        workingDirectory,
      ],
      environment: <String, String>{
        'PATH': getPathVariable(),
        'USER_CPP_OPTS': '-std=c++17',
        ...environment,
      },
    );
  }

  Future<RunResult> buildNative(
    String workingDirectory, {
    required String configuration,
    required String arch,
    String? compiler,
    List<String> predefines = const <String>[],
    List<String> extraOptions = const <String>[],
    String? rootstrap,
    Map<String, String> environment = const <String, String>{},
  }) {
    return _processUtils.run(
      <String>[
        tizenCli.path,
        'build-native',
        '-C',
        configuration,
        '-a',
        arch,
        '-c',
        compiler ?? defaultNativeCompiler,
        for (final String macro in predefines) ...<String>['-d', macro],
        if (extraOptions.isNotEmpty) ...<String>['-e', extraOptions.join(' ')],
        if (rootstrap != null) ...<String>['-r', rootstrap],
        '--',
        workingDirectory,
      ],
      environment: <String, String>{
        'PATH': getPathVariable(),
        'USER_CPP_OPTS': '-std=c++17',
        ...environment,
      },
    );
  }

  Future<RunResult> package(
    String workingDirectory, {
    String type = 'tpk',
    String? reference,
    String? extraDir,
    String? sign,
  }) {
    return _processUtils.run(<String>[
      tizenCli.path,
      'package',
      '-t',
      type,
      if (sign != null) ...<String>['-s', sign],
      if (reference != null) ...<String>['-r', reference],
      if (extraDir != null) ...<String>['-e', extraDir],
      '--',
      workingDirectory,
    ]);
  }

  Future<RunResult> tzBuild(
    String workingDirectory, {
    String? buildType,
    String? signingProfile,
  }) async {
    final RunResult result = await _processUtils.run(
      <String>[
        tzCli.path,
        'set',
        if (buildType != null) ...<String>['-b', buildType],
        if (signingProfile != null) ...<String>['-s', signingProfile],
      ],
      workingDirectory: workingDirectory,
    );

    if (result.exitCode != 0) {
      return result;
    }

    return _processUtils.run(
      <String>[
        tzCli.path,
        'build',
      ],
      workingDirectory: workingDirectory,
    );
  }

  Rootstrap getRootstrap({
    required String profile,
    String? apiVersion,
    required String arch,
  }) {
    apiVersion ??= '6.0';

    double versionToDouble(String versionString) {
      final double? version = double.tryParse(versionString);
      if (version == null) {
        throwToolExit('The API version $versionString is invalid.');
      }
      return version;
    }

    if (versionToDouble(apiVersion) < 6.0) {
      throwToolExit('Not supported API version: $apiVersion');
    }

    switch (profile) {
      case 'common':
        if (versionToDouble(apiVersion) >= 8.0) {
          // Note: Starting with Tizen 8.0, the unified "tizen" profile is used.
          profile = 'tizen';
        } else {
          profile = arch == 'x86' ? 'mobile' : 'iot-headed';
        }
      case 'tv':
        // Note: The tv-samsung rootstrap is not publicly available.
        profile = 'tv-samsung';
      case 'mobile':
        if (versionToDouble(apiVersion) >= 8.0) {
          profile = 'tizen';
        }
    }

    final String type = switch (arch) {
      'x64' => 'emulator64',
      'x86' => 'emulator',
      'arm64' => 'device64',
      _ => 'device',
    };

    Rootstrap findRootstrap(String profile, String apiVersion, String type) {
      final String id = '$profile-$apiVersion-$type.core';
      final Directory rootDir = platformsDirectory
          .childDirectory('tizen-$apiVersion')
          .childDirectory(profile)
          .childDirectory('rootstraps')
          .childDirectory(id);
      return Rootstrap(id, rootDir);
    }

    Rootstrap rootstrap = findRootstrap(profile, apiVersion, type);
    if (!rootstrap.isValid && profile == 'tv-samsung') {
      _logger.printTrace('TV SDK could not be found.');
      if (versionToDouble(apiVersion) >= 8.0) {
        profile = 'tizen';
      } else {
        profile = arch == 'x86' ? 'mobile' : 'iot-headed';
      }
      rootstrap = findRootstrap(profile, apiVersion, type);
    }

    if (!rootstrap.isValid) {
      final String profileUpperCase = profile.toUpperCase().replaceAll('HEADED', 'Headed');
      throwToolExit(
        'The rootstrap ${rootstrap.id} could not be found.\n'
        'To install missing package(s), run:\n'
        '${packageManagerCli.path} install $profileUpperCase-$apiVersion-NativeAppDevelopment-CLI',
      );
    }
    _logger.printTrace('Found a rootstrap: ${rootstrap.id}');

    return Rootstrap(rootstrap.id, rootstrap.rootDirectory);
  }
}

/// Tizen rootstrap definition.
///
/// The rootstrap (or sysroot), which is downloaded as part of Tizen native SDK,
/// contains a set of headers and libraries required for cross building Tizen
/// native apps and libraries.
class Rootstrap {
  const Rootstrap(this.id, this.rootDirectory);

  final String id;
  final Directory rootDirectory;

  bool get isValid => rootDirectory.existsSync();
}

/// Converts [arch] to an arch name that corresponds to the `BUILD_ARCH`
/// value used by the Tizen native builder.
String getTizenBuildArch(String arch) {
  switch (arch) {
    case 'arm':
      return 'armel';
    case 'arm64':
      return 'aarch64';
    case 'x86':
      return 'i586';
    case 'x64':
      return 'x86_64';
    default:
      return arch;
  }
}

/// Converts [arch] to an arch name that the Tizen CLI tool expects.
String getTizenCliArch(String arch) {
  switch (arch) {
    case 'arm':
      return 'arm';
    case 'arm64':
      return 'aarch64';
    case 'x86':
      return 'x86';
    case 'x64':
      return 'x86_64';
    default:
      return arch;
  }
}

class SecurityProfiles {
  SecurityProfiles._(this.profiles, {required this.active});

  @visibleForTesting
  SecurityProfiles.test(String? profile)
      : profiles = profile == null ? <String>[] : <String>[profile],
        active = profile;

  static SecurityProfiles? parseFromXml(File xmlFile) {
    if (!xmlFile.existsSync()) {
      return null;
    }

    final String data = xmlFile.readAsStringSync().trim();
    if (data.isEmpty) {
      return null;
    }

    XmlDocument document;
    try {
      document = XmlDocument.parse(data);
    } on XmlException catch (ex) {
      globals.printError('Failed to parse ${xmlFile.basename}: $ex');
      return null;
    }

    String? active = document.rootElement.getAttribute('active');
    if (active != null && active.isEmpty) {
      active = null;
    }

    final List<String> profiles = <String>[];
    for (final XmlElement profile in document.rootElement.findAllElements('profile')) {
      final String? name = profile.getAttribute('name');
      if (name != null) {
        profiles.add(name);
      }
    }

    return SecurityProfiles._(profiles, active: active);
  }

  final List<String> profiles;
  final String? active;

  bool contains(String name) => profiles.contains(name);
}

Map<String, String> parseIniFile(File file) {
  final Map<String, String> result = <String, String>{};
  if (file.existsSync()) {
    for (String line in file.readAsLinesSync()) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#') || !line.contains('=')) {
        continue;
      }
      final int splitIndex = line.indexOf('=');
      final String name = line.substring(0, splitIndex).trim();
      final String value = line.substring(splitIndex + 1).trim();
      result[name] = value;
    }
  }
  return result;
}
