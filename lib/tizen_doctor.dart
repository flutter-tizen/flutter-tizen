// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/android/android_studio_validator.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/doctor.dart';
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

  bool _checkPackages(List<ValidationMessage> messages) {
    // tizenSdk is not null here.
    final String platformVersion = tizenSdk.defaultTargetPlatform;
    final String gccVersion = tizenSdk.defaultGccVersion;

    final bool hasTizenCli = tizenSdk.tizenCli.existsSync();
    final bool hasNativeToolchain = tizenSdk.toolsDirectory
        .childDirectory('arm-linux-gnueabi-gcc-$gccVersion')
        .existsSync();
    final bool hasPlatformRootstrap = tizenSdk.platformsDirectory
        .childDirectory('tizen-$platformVersion')
        .childDirectory('wearable')
        .childDirectory('rootstraps')
        .existsSync();

    if (hasTizenCli && hasPlatformRootstrap && hasNativeToolchain) {
      return true;
    } else {
      messages.add(ValidationMessage.error(
        <String>[
          'Install missing packages with Tizen Package Manager or package-manager-cli:',
          if (!hasTizenCli) '- NativeCLI',
          if (!hasNativeToolchain) '- NativeToolchain-Gcc-$gccVersion',
          if (!hasPlatformRootstrap)
            '- WEARABLE-$platformVersion-NativeAppDevelopment-CLI',
        ].join('\n'),
      ));
      return false;
    }
  }

  /// See: [AndroidValidator.validate] in `android_workflow.dart`
  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];

    if (getSdbPath() == null) {
      messages.add(const ValidationMessage.error(
        'Unable to locate Tizen SDK.\n'
        'Install Tizen Studio from: https://developer.tizen.org/development/tizen-studio/download\n'
        'Make sure the tools path (<tizen-studio>/tools) is in your PATH after installation.',
      ));
      return ValidationResult(ValidationType.missing, messages);
    }

    if (!_checkPackages(messages)) {
      return ValidationResult(ValidationType.partial, messages);
    }

    if (getDotnetCliPath() == null) {
      messages.add(const ValidationMessage.error(
        '.NET CLI is required for building Tizen applications.\n'
        'Install .NET for your Linux distribution from: https://dotnet.microsoft.com/download',
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
