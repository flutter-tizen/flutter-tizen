// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/doctor_validator.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:meta/meta.dart';

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
  TizenValidator() : super('Tizen toolchain - develop for Tizen devices');

  bool _validatePackages(List<ValidationMessage> messages) {
    // tizenSdk is not null here.
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

    if (tizenSdk == null) {
      messages.add(const ValidationMessage.error(
        'Unable to locate Tizen SDK.\n'
        'Install Tizen Studio from: https://developer.tizen.org/development/tizen-studio/download\n'
        'If the Tizen SDK has been installed to a custom location, set TIZEN_SDK to that location.',
      ));
      return ValidationResult(ValidationType.missing, messages);
    }

    final double sdkVersion = double.tryParse(tizenSdk.sdkVersion ?? '');
    if (sdkVersion == null) {
      messages.add(const ValidationMessage.error(
        'Unknown Tizen Studio version.\n'
        'The version file is missing or corrupted. Consider updating or reinstalling Tizen Studio.',
      ));
      return ValidationResult(ValidationType.missing, messages);
    } else if (sdkVersion < 4.0) {
      messages.add(ValidationMessage.error(
        'A newer version of Tizen Studio is required. To update, run:\n'
        '${tizenSdk.packageManagerCli.path} update',
      ));
      return ValidationResult(ValidationType.missing, messages);
    } else {
      messages.add(ValidationMessage(
        'Tizen Studio $sdkVersion at ${tizenSdk.directory.path}',
      ));
    }

    if (!_validatePackages(messages)) {
      return ValidationResult(ValidationType.partial, messages);
    }

    if (dotnetCli != null && globals.processManager.canRun(dotnetCli.path)) {
      // TODO(swift-kim): Extract numbers only and compare with the minimum SDK
      // version using Version.parse().
      final String dotnetVersion = globals.processUtils
          .runSync(<String>[dotnetCli.path, '--version'])
          .stdout
          .trim();
      messages.add(ValidationMessage(
        '.NET SDK $dotnetVersion at ${dotnetCli.path}',
      ));
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
  bool get canLaunchDevices => _tizenSdk != null;

  @override
  bool get canListDevices => _tizenSdk != null;

  @override
  bool get canListEmulators =>
      _tizenSdk != null && _tizenSdk.emCli.existsSync();
}
