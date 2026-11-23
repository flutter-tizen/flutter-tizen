// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/commands/run.dart';
import 'package:flutter_tools/src/context/tool_context.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/target_devices.dart';

import '../tizen_cache.dart';
import '../tizen_device.dart';
import '../tizen_plugins.dart';

class TizenRunCommand extends RunCommand with DartPluginRegistry, TizenRequiredArtifacts {
  TizenRunCommand({super.toolContext, super.verboseHelp});

  @override
  Future<List<Device>?> findAllTargetDevices({
    bool? canPrompt,
    bool includeDevicesUnsupportedByProject = false,
  }) async {
    final List<Device> devices = await globals.deviceManager!.getDevices();
    final ToolContext toolContext = this.toolContext!;
    return TargetDevices(
      deviceManager: globals.deviceManager!,
      doctor: globals.doctor!,
      toolContext: _withLogger(
        toolContext,
        TizenDeviceLogger(logger: toolContext.logger, devices: devices),
      ),
      deviceConnectionInterface: deviceConnectionInterface,
    ).findAllTargetDevices(
      canPrompt: canPrompt ?? !outputMachineFormat,
      deviceDiscoveryTimeout: deviceDiscoveryTimeout,
      includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
    );
  }
}

ToolContext _withLogger(ToolContext context, Logger logger) {
  return ToolContext(
    artifacts: context.artifacts,
    botDetector: context.botDetector,
    cache: context.cache,
    config: context.config,
    customDevicesConfig: context.customDevicesConfig,
    flutterVersion: context.flutterVersion,
    fs: context.fs,
    git: context.git,
    localEngineLocator: context.localEngineLocator,
    logger: logger,
    nativeAssetsBuilder: context.nativeAssetsBuilder,
    os: context.os,
    outputPreferences: context.outputPreferences,
    persistentToolState: context.persistentToolState,
    platform: context.platform,
    preRunValidator: context.preRunValidator,
    processInfo: context.processInfo,
    processManager: context.processManager,
    processUtils: context.processUtils,
    projectFactory: context.projectFactory,
    shutdownHooks: context.shutdownHooks,
    signals: context.signals,
    stdio: context.stdio,
    systemClock: context.systemClock,
    terminal: context.terminal,
    userMessages: context.userMessages,
  );
}

/// A [Logger] that fixes the device information for Tizen devices.
class TizenDeviceLogger extends DelegatingLogger {
  TizenDeviceLogger({
    required Logger logger,
    required List<Device> devices,
  })  : _devices = devices.whereType<TizenDevice>().toList(growable: false),
        super(logger);

  final List<TizenDevice> _devices;

  @override
  void printStatus(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    bool? newline,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    for (final TizenDevice device in _devices) {
      if (message.contains(device.name) && message.contains('Tizen')) {
        message = message
            .replaceFirst(
              '(${Category.mobile})',
              '(${device.deviceProfile})${device.deviceProfile == 'tv' ? '    ' : ''}',
            )
            .replaceFirst(
              TargetPlatform.tester.getName(),
              'tizen-${device.architecture}${device.architecture == 'arm64' ? '   ' : '     '}',
            );
      }
    }

    super.printStatus(
      message,
      emphasis: emphasis,
      color: color,
      newline: newline,
      indent: indent,
      hangingIndent: hangingIndent,
      wrap: wrap,
    );
  }
}
