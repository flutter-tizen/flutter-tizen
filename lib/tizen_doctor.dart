// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/version.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/doctor_validator.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/version.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'executable.dart';
import 'tizen_sdk.dart';

TizenWorkflow get tizenWorkflow => context.get<TizenWorkflow>();
TizenValidator get tizenValidator => context.get<TizenValidator>();

/// See: [_DefaultDoctorValidatorsProvider] in `doctor.dart`
class TizenDoctorValidatorsProvider extends DoctorValidatorsProvider {
  @override
  List<DoctorValidator> get validators {
    final List<DoctorValidator> validators =
        DoctorValidatorsProvider.defaultInstance.validators;
    return <DoctorValidator>[
      validators.first,
      tizenValidator,
      ...validators.sublist(1)
    ];
  }

  @override
  List<Workflow> get workflows => <Workflow>[
        ...DoctorValidatorsProvider.defaultInstance.workflows,
        tizenWorkflow,
      ];
}

/// A validator that checks for Tizen SDK and .NET CLI installation.
class TizenValidator extends DoctorValidator {
  TizenValidator({
    @required Logger logger,
    @required ProcessManager processManager,
  })  : _processManager = processManager,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        super('Tizen toolchain - develop for Tizen devices');

  final ProcessManager _processManager;
  final ProcessUtils _processUtils;

  bool _validatePackages(List<ValidationMessage> messages) {
    assert(tizenSdk != null);
    final String gccVersion = tizenSdk.defaultGccVersion;
    final String packageManager = tizenSdk.packageManagerCli.path;
    final List<String> missingPackages = <String>[];

    if (!tizenSdk.tizenCli.existsSync()) {
      missingPackages.add('NativeCLI');
    }
    if (!tizenSdk.toolsDirectory
        .childDirectory('arm-linux-gnueabi-gcc-$gccVersion')
        .existsSync()) {
      missingPackages.add('NativeToolchain-Gcc-$gccVersion');
    }
    if (!tizenSdk.platformsDirectory
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

    final FlutterVersion version = _FlutterTizenVersion();
    messages.add(ValidationMessage(globals.userMessages.flutterRevision(
      version.frameworkRevisionShort,
      version.frameworkAge,
      version.frameworkCommitDate,
    )));
    messages.add(ValidationMessage(
        globals.userMessages.engineRevision(version.engineRevisionShort)));

    if (tizenSdk == null) {
      messages.add(const ValidationMessage.error(
        'Unable to locate Tizen SDK.\n'
        'Install Tizen Studio from: https://developer.tizen.org/development/tizen-studio/download\n'
        'If the Tizen SDK has been installed to a custom location, set TIZEN_SDK to that location.',
      ));
      return ValidationResult(ValidationType.missing, messages);
    }

    final Version sdkVersion = Version.parse(tizenSdk.sdkVersion);
    if (sdkVersion != null && sdkVersion < Version(4, 0, 0)) {
      messages.add(ValidationMessage.error(
        'A newer version of Tizen Studio is required. To update, run:\n'
        '${tizenSdk.packageManagerCli.path} update',
      ));
      return ValidationResult(ValidationType.missing, messages);
    } else {
      final String versionText = sdkVersion != null ? ' $sdkVersion' : '';
      messages.add(ValidationMessage(
        'Tizen Studio$versionText at ${tizenSdk.directory.path}',
      ));
    }

    if (!_validatePackages(messages)) {
      return ValidationResult(ValidationType.partial, messages);
    }

    if (dotnetCli != null && _processManager.canRun(dotnetCli.path)) {
      final Version dotnetVersion = Version.parse(
        _processUtils
            .runSync(<String>[dotnetCli.path, '--version'])
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
          '.NET SDK $dotnetVersion at ${dotnetCli.path}',
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
    @required TizenSdk tizenSdk,
    @required OperatingSystemUtils operatingSystemUtils,
  })  : _tizenSdk = tizenSdk,
        _operatingSystemUtils = operatingSystemUtils;

  final TizenSdk _tizenSdk;
  final OperatingSystemUtils _operatingSystemUtils;

  @override
  bool get appliesToHostPlatform =>
      _operatingSystemUtils.hostPlatform != HostPlatform.linux_arm64;

  @override
  bool get canLaunchDevices => appliesToHostPlatform && _tizenSdk != null;

  @override
  bool get canListDevices => appliesToHostPlatform && _tizenSdk != null;

  @override
  bool get canListEmulators => canListDevices && _tizenSdk.emCli.existsSync();
}

class _FlutterTizenVersion extends FlutterVersion {
  _FlutterTizenVersion() : super(workingDirectory: rootPath);

  /// See: [Cache.getVersionFor] in `cache.dart`
  String _getVersionFor(String artifactName) {
    final File versionFile = globals.fs
        .directory(rootPath)
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
    final String engineRevision = _getVersionFor('engine');
    if (engineRevision == null) {
      throwToolExit('Could not determine engine revision.');
    }
    return engineRevision;
  }

  /// See: [_runGit] in `version.dart`
  String _runGit(String command) => globals.processUtils
      .runSync(command.split(' '), workingDirectory: rootPath)
      .stdout
      .trim();

  /// This should be overriden because [FlutterVersion._latestGitCommitDate]
  /// runs the git log command in the `Cache.flutterRoot` directory.
  @override
  String get frameworkCommitDate => _runGit(
      'git -c log.showSignature=false log -n 1 --pretty=format:%ad --date=iso');
}
