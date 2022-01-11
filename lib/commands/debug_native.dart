// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/signals.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_device.dart';
import '../tizen_sdk.dart';
import '../tizen_tpk.dart';
import '../vscode_helper.dart';

const String kWikiPageUrl =
    "https://github.com/flutter-tizen/flutter-tizen/wiki/Debugging-app's-native-code";

class DebugNativeCommand extends FlutterCommand {
  DebugNativeCommand({this.hidden = false}) {
    requiresPubspecYaml();
  }

  @override
  String get name => 'debug-native';

  @override
  List<String> get aliases => const <String>['debug_native'];

  @override
  String get description => 'Attach gdbserver to a running app (Tizen-only).';

  @override
  String get category => FlutterCommandCategory.tools;

  @override
  final bool hidden;

  TizenDevice _device;
  FlutterProject _project;
  TizenTpk _package;

  final Completer<void> _finished = Completer<void>();

  @override
  Future<void> validateCommand() async {
    final Device device = await findTargetDevice();
    if (device == null) {
      throwToolExit('No target device found.');
    }
    if (device is! TizenDevice) {
      throwToolExit('The selected device is not a Tizen device.');
    }
    _device = device as TizenDevice;
    if (_device.usesSecureProtocol) {
      throwToolExit('Not supported device.');
    }
    return super.validateCommand();
  }

  @override
  Future<FlutterCommandResult> verifyThenRunCommand(String commandPath) async {
    _project = FlutterProject.current();
    _package = TizenTpk.fromProject(_project);
    if (_package.isDotnet) {
      throwToolExit(
        'Not supported app language.\n\n'
        'See $kWikiPageUrl for detailed usage.',
      );
    }
    return super.verifyThenRunCommand(commandPath);
  }

  Future<void> _startGdbServer(
    String applicationId,
    int debugPort,
    String processId,
  ) async {
    final List<String> command = _device.sdbCommand(<String>[
      'shell',
      'launch_debug',
      applicationId,
      '__AUL_SDK__',
      'ATTACH',
      '__LAUNCH_APP_MODE__',
      'SYNC',
      '__DLP_GDBSERVER_PATH__',
      '/home/owner/share/tmp/sdk_tools/gdbserver/gdbserver',
      '__DLP_ATTACH_ARG__',
      '--attach,:$debugPort,$processId',
    ]);
    final Process process = await globals.processManager.start(command);

    final Completer<void> completer = Completer<void>();
    process.stdout
        .transform<String>(const Utf8Decoder())
        .transform<String>(const LineSplitter())
        .listen((String line) {
      if (!completer.isCompleted) {
        if (line.contains("Can't bind address") ||
            line.contains('Cannot attach to process')) {
          completer.completeError(line);
        } else if (line.contains('Listening on port')) {
          completer.complete();
        }
      }
      if (!_finished.isCompleted) {
        if (line.contains('Detaching from process') ||
            line.contains('GDBserver exiting')) {
          _finished.complete();
        }
      }
      globals.printStatus(line);
    });
    process.stderr
        .transform<String>(const Utf8Decoder())
        .transform<String>(const LineSplitter())
        .listen((String line) {
      if (!completer.isCompleted) {
        completer.completeError(line);
      }
      globals.printError(line);
    });

    try {
      await completer.future.timeout(const Duration(seconds: 10));
    } on Exception catch (error) {
      throwToolExit('Could not start gdbserver: $error');
    }
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    final File program = _project.directory
        .childDirectory('build')
        .childDirectory('tizen')
        .childDirectory('tpk')
        .childDirectory('tpkroot')
        .childDirectory('bin')
        .childFile('runner');
    if (!program.existsSync()) {
      throwToolExit(
        'Could not find the runner executable.\n'
        'Did you build and install the app to the device?',
      );
    }
    if (tizenSdk == null) {
      throwToolExit('Unable to locate Tizen SDK.');
    }

    // Forward a port to allow communication between gdb and gdbserver.
    final int debugPort = await globals.os.findFreePort();
    await _device.portForwarder.forward(debugPort, hostPort: debugPort);

    // Find the running app's process ID.
    final RunResult result =
        await _device.runSdbAsync(<String>['shell', 'app_launcher', '-S']);
    final RegExp pattern = RegExp('${_package.applicationId} \\(([0-9]+)\\)');
    final Match match = pattern.firstMatch(result.stdout);
    if (match == null) {
      throwToolExit('The app is not running.');
    }
    final String processId = match.group(1);

    if (!await _device.installGdbServer()) {
      return FlutterCommandResult.fail();
    }
    await _startGdbServer(_package.applicationId, debugPort, processId);

    final File gdb = tizenSdk.getGdbExecutable(_device.architecture);
    updateLaunchJsonWithRemoteDebuggingInfo(
      _project,
      program: program,
      gdbPath: gdb.path,
      debugPort: debugPort,
    );

    final String escapeCharacter = globals.platform.isWindows ? '`' : r'\';
    globals.printStatus('''
gdbserver is listening for a debug connection on port $debugPort.

Keep this program running until your debug session is closed.

GDB launch command:
${gdb.path} $escapeCharacter
  "${program.path}" $escapeCharacter
  -ex "set auto-solib-add off" $escapeCharacter
  -ex "target remote :$debugPort" $escapeCharacter
  -ex "shared /opt/usr/globalapps"

Using the VS Code debugger:
1. Open the project folder in VS Code.
2. Click the Run and Debug icon in the left menu bar, and make sure "$kConfigNameGdb" is selected.
3. Click ▷ or press F5 to start debugging.

For detailed instructions, see: $kWikiPageUrl
''');

    _registerSignalHandlers(_cleanUp);
    globals.terminal.singleCharMode = true;
    globals.terminal.keystrokes.listen((String key) async {
      switch (key.trim()) {
        case 'q':
        case 'Q':
          globals.printStatus('Quit');
          _finished.complete();
          break;
      }
    });
    await _finished.future;
    await _cleanUp();

    return FlutterCommandResult.success();
  }

  void _registerSignalHandlers(SignalHandler onSignal) {
    globals.signals.addHandler(ProcessSignal.sigint, onSignal);
    globals.signals.addHandler(ProcessSignal.sigterm, onSignal);
  }

  Future<void> _cleanUp([ProcessSignal signal]) async {
    globals.terminal.singleCharMode = false;
    await _device?.dispose();
  }
}
