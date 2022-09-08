// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/user_messages.dart';
import 'package:flutter_tools/src/base/version.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/doctor_validator.dart';
import 'package:flutter_tools/src/version.dart';
import 'package:process/process.dart';

import 'tizen_sdk.dart';

TizenWorkflow? get tizenWorkflow => context.get<TizenWorkflow>();
TizenValidator? get tizenValidator => context.get<TizenValidator>();

/// See: [_DefaultDoctorValidatorsProvider] in `doctor.dart`
class TizenDoctorValidatorsProvider extends DoctorValidatorsProvider {
  @override
  List<DoctorValidator> get validators {
    final List<DoctorValidator> validators =
        DoctorValidatorsProvider.defaultInstance.validators;
    return <DoctorValidator>[
      validators.first,
      tizenValidator!,
      ...validators.sublist(1)
    ];
  }

  @override
  List<Workflow> get workflows => <Workflow>[
        ...DoctorValidatorsProvider.defaultInstance.workflows,
        tizenWorkflow!,
      ];
}

/// A validator that checks for Tizen SDK and .NET CLI installation.
class TizenValidator extends DoctorValidator {
  TizenValidator({
    required TizenSdk? tizenSdk,
    required File? dotnetCli,
    required FileSystem fileSystem,
    required Logger logger,
    required ProcessManager processManager,
    required UserMessages userMessages,
  })  : _tizenSdk = tizenSdk,
        _dotnetCli = dotnetCli,
        _fileSystem = fileSystem,
        _processManager = processManager,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        _userMessages = userMessages,
        super('Tizen toolchain - develop for Tizen devices');

  final TizenSdk? _tizenSdk;
  final File? _dotnetCli;
  final FileSystem _fileSystem;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;
  final UserMessages _userMessages;

  bool _validatePackages(List<ValidationMessage> messages) {
    final String gccVersion = _tizenSdk!.defaultGccVersion;
    final String packageManager = _tizenSdk!.packageManagerCli.path;
    final List<String> missingPackages = <String>[];

    if (!_tizenSdk!.tizenCli.existsSync()) {
      missingPackages.add('NativeCLI');
    }
    if (!_tizenSdk!.toolsDirectory
        .childDirectory('arm-linux-gnueabi-gcc-$gccVersion')
        .existsSync()) {
      missingPackages.add('NativeToolchain-Gcc-$gccVersion');
    }
    if (!_tizenSdk!.platformsDirectory
        .childDirectory('tizen-4.0')
        .childDirectory('wearable')
        .childDirectory('rootstraps')
        .existsSync()) {
      missingPackages.add('WEARABLE-4.0-NativeAppDevelopment-CLI');
    }

    if (missingPackages.isNotEmpty) {
      messages.add(ValidationMessage.error('To install missing packages, run:\n'
          '$packageManager install ${missingPackages.join(' ')}'));
      return false;
    }
    return true;
  }

  /// See: [AndroidValidator.validate] in `android_workflow.dart`
  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];

    final FlutterVersion version = _FlutterTizenVersion(
      workingDirectory: _fileSystem.directory(Cache.flutterRoot).parent,
      processUtils: _processUtils,
    );
    messages.add(ValidationMessage(_userMessages.flutterRevision(
      version.frameworkRevisionShort,
      version.frameworkAge,
      version.frameworkCommitDate,
    )));
    messages.add(ValidationMessage(
        _userMessages.engineRevision(version.engineRevision)));

    if (_tizenSdk == null) {
      messages.add(const ValidationMessage.error(
        'Unable to locate Tizen SDK.\n'
        'Install Tizen Studio from: https://developer.tizen.org/development/tizen-studio/download\n'
        'If the Tizen SDK has been installed to a custom location, set TIZEN_SDK to that location.',
      ));
      return ValidationResult(ValidationType.missing, messages);
    }

    final Version? sdkVersion = Version.parse(_tizenSdk!.sdkVersion);
    if (sdkVersion != null && sdkVersion < Version(4, 0, 0)) {
      messages.add(ValidationMessage.error(
        'A newer version of Tizen Studio is required. To update, run:\n'
        '${_tizenSdk!.packageManagerCli.path} update',
      ));
      return ValidationResult(ValidationType.missing, messages);
    } else {
      final String versionText = sdkVersion != null ? ' $sdkVersion' : '';
      messages.add(ValidationMessage(
        'Tizen Studio$versionText at ${_tizenSdk!.directory.path}',
      ));
    }

    if (!_validatePackages(messages)) {
      return ValidationResult(ValidationType.partial, messages);
    }

    if (_dotnetCli != null && _processManager.canRun(_dotnetCli!.path)) {
      final Version? dotnetVersion = Version.parse(
        _processUtils
            .runSync(<String>[_dotnetCli!.path, '--version'])
            .stdout
            .trim(),
      );
      if (dotnetVersion == null || dotnetVersion < Version(3, 0, 0)) {
        messages.add(const ValidationMessage.error(
          'A newer version of the .NET SDK is required.\n'
          'Install the latest release from: https://dotnet.microsoft.com/download',
        ));
        return ValidationResult(ValidationType.missing, messages);
      } else {
        messages.add(ValidationMessage(
          '.NET SDK $dotnetVersion at ${_dotnetCli!.path}',
        ));
      }
    } else {
      messages.add(const ValidationMessage.error(
        'Unable to find the .NET CLI executable in your PATH.\n'
        'Install the latest .NET SDK from: https://dotnet.microsoft.com/download',
      ));
      return ValidationResult(ValidationType.missing, messages);
    }

    return ValidationResult(ValidationType.installed, messages);
  }
}

/// The Tizen-specific implementation of a [Workflow].
///
/// See: [AndroidWorkflow] in `android_workflow.dart`
class TizenWorkflow extends Workflow {
  TizenWorkflow({
    required TizenSdk? tizenSdk,
    required OperatingSystemUtils operatingSystemUtils,
  })  : _tizenSdk = tizenSdk,
        _operatingSystemUtils = operatingSystemUtils;

  final TizenSdk? _tizenSdk;
  final OperatingSystemUtils _operatingSystemUtils;

  @override
  bool get appliesToHostPlatform =>
      _operatingSystemUtils.hostPlatform != HostPlatform.linux_arm64;

  @override
  bool get canLaunchDevices => appliesToHostPlatform && _tizenSdk != null;

  @override
  bool get canListDevices => appliesToHostPlatform && _tizenSdk != null;

  @override
  bool get canListEmulators => canListDevices && _tizenSdk!.emCli.existsSync();
}

class _FlutterTizenVersion extends FlutterVersion {
  _FlutterTizenVersion({
    required Directory workingDirectory,
    required ProcessUtils processUtils,
  })  : _workingDirectory = workingDirectory,
        _processUtils = processUtils,
        super(workingDirectory: workingDirectory.path);

  final Directory _workingDirectory;
  final ProcessUtils _processUtils;

  /// See: [Cache.getVersionFor] in `cache.dart`
  String? _getVersionFor(String artifactName) {
    final File versionFile = _workingDirectory
        .childDirectory('bin')
        .childDirectory('internal')
        .childFile('$artifactName.version');
    return versionFile.existsSync()
        ? versionFile.readAsStringSync().trim()
        : null;
  }

  /// Source: [Cache.engineRevision] in `cache.dart`
  @override
  String get engineRevision {
    final String? engineRevision = _getVersionFor('engine');
    if (engineRevision == null) {
      throwToolExit('Could not determine engine revision.');
    }
    return engineRevision;
  }

  /// See: [_runGit] in `version.dart`
  String _runGit(String command) => _processUtils
      .runSync(command.split(' '), workingDirectory: _workingDirectory.path)
      .stdout
      .trim();

  /// This should be overriden because [FlutterVersion._gitCommitDate] runs
  /// the git log command in the [Cache.flutterRoot] directory.
  @override
  String get frameworkCommitDate => _runGit(
      'git -c log.showSignature=false log -n 1 --pretty=format:%ad --date=iso');
}
