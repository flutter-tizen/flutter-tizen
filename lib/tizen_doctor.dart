// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/android/android_studio_validator.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/doctor_validator.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import 'tizen_sdk.dart';

TizenWorkflow get tizenWorkflow => context.get<TizenWorkflow>();
TizenValidator get tizenValidator => context.get<TizenValidator>();

/// See: [_DefaultDoctorValidatorsProvider] in `doctor.dart`
class TizenDoctorValidatorsProvider extends DoctorValidatorsProvider {
  @override
  List<DoctorValidator> get validators {
    final List<DoctorValidator> validators =
        DoctorValidatorsProvider.defaultInstance.validators;
    for (final DoctorValidator validator in validators) {
      // Append before any IDE validators.
      if (validator is AndroidStudioValidator ||
          validator is NoAndroidStudioValidator) {
        validators.insert(validators.indexOf(validator), tizenValidator);
        break;
      }
    }
    return validators;
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

    final double sdkVersion = double.tryParse(tizenSdk.sdkVersion) ?? 0;
    if (sdkVersion < 4.0) {
      messages.add(ValidationMessage.error(
        'A newer version of Tizen Studio is required. To update, run:\n'
        '${tizenSdk.packageManagerCli.path} update',
      ));
      return ValidationResult(ValidationType.missing, messages);
    }

    messages.add(ValidationMessage(
        'Tizen Studio ${tizenSdk.sdkVersion} at ${tizenSdk.directory.path}'));

    if (!_validatePackages(messages)) {
      return ValidationResult(ValidationType.partial, messages);
    }

    if (dotnetCli == null) {
      messages.add(const ValidationMessage.error(
        '.NET CLI is required for building Tizen applications.\n'
        'Install the latest .NET SDK from: https://dotnet.microsoft.com/download',
      ));
      return ValidationResult(ValidationType.missing, messages);
    }

    messages.add(ValidationMessage('.NET CLI executable at ${dotnetCli.path}'));

    return ValidationResult(ValidationType.installed, messages);
  }
}

/// The Tizen-specific implementation of a [Workflow].
///
/// See: [AndroidWorkflow] in `android_workflow.dart`
class TizenWorkflow extends Workflow {
  @override
  bool get appliesToHostPlatform =>
      globals.platform.isLinux ||
      globals.platform.isWindows ||
      globals.platform.isMacOS;

  @override
  bool get canLaunchDevices => tizenSdk != null;

  @override
  bool get canListDevices => tizenSdk != null;

  @override
  bool get canListEmulators => tizenSdk != null && tizenSdk.emCli.existsSync();
}
