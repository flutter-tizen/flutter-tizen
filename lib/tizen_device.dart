// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_device.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/device_port_forwarder.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/protocol_discovery.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:process/process.dart';

import 'tizen_builder.dart';
import 'tizen_sdk.dart';
import 'tizen_tpk.dart';

/// Tizen device implementation.
///
/// See: [AndroidDevice] in `android_device.dart`
class TizenDevice extends Device {
  TizenDevice(
    String id, {
    String modelId,
    @required Logger logger,
    @required TizenSdk tizenSdk,
    @required ProcessManager processManager,
  })  : _modelId = modelId,
        _logger = logger,
        _tizenSdk = tizenSdk,
        _processManager = processManager,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        super(id,
            category: Category.mobile,
            platformType: PlatformType.linux,
            ephemeral: true);

  final String _modelId;
  final Logger _logger;
  final TizenSdk _tizenSdk;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;

  Map<String, String> _capabilities;
  TizenDlogReader _logReader;
  TizenDevicePortForwarder _portForwarder;

  /// Source: [AndroidDevice.adbCommandForDevice] in `android_device.dart`
  List<String> sdbCommand(List<String> args) {
    return <String>[_tizenSdk.sdb.path, '-s', id, ...args];
  }

  /// See: [AndroidDevice.runAdbCheckedSync] in `android_device.dart`
  RunResult runSdbSync(
    List<String> params, {
    bool checked = true,
  }) {
    return _processUtils.runSync(sdbCommand(params), throwOnError: checked);
  }

  /// See: [AndroidDevice.runAdbCheckedAsync] in `android_device.dart`
  Future<RunResult> runSdbAsync(
    List<String> params, {
    bool checked = true,
  }) async {
    return _processUtils.run(sdbCommand(params), throwOnError: checked);
  }

  String getCapability(String name) {
    if (_capabilities == null) {
      final String stdout = runSdbSync(<String>['capability']).stdout.trim();

      final Map<String, String> capabilities = <String, String>{};
      for (final String line in LineSplitter.split(stdout)) {
        final List<String> splitLine = line.trim().split(':');
        if (splitLine.length >= 2) {
          capabilities[splitLine[0]] = splitLine[1];
        }
      }
      _capabilities = capabilities;
    }
    return _capabilities[name];
  }

  static const List<String> _emulatorArchs = <String>['x86'];

  @override
  Future<bool> get isLocalEmulator async =>
      _emulatorArchs.contains(getCapability('cpu_arch'));

  @override
  Future<String> get emulatorId async =>
      (await isLocalEmulator) ? _modelId : null;

  @override
  Future<TargetPlatform> get targetPlatform async {
    // Use tester as a platform identifer for Tizen.
    // There's currently no other choice because getNameForTargetPlatform()
    // throws an error for unknown platform types.
    return TargetPlatform.tester;
  }

  @override
  Future<bool> supportsRuntimeMode(BuildMode buildMode) async {
    if (await isLocalEmulator) {
      return buildMode == BuildMode.debug;
    } else {
      return buildMode != BuildMode.jitRelease;
    }
  }

  String get platformVersion {
    final String version = getCapability('platform_version');

    // Truncate if the version string is like "x.y.z.v".
    final List<String> segments = version.split('.');
    if (segments.length > 2) {
      return segments.sublist(0, 2).join('.');
    }
    return version;
  }

  @override
  Future<String> get sdkNameAndVersion async => 'Tizen $platformVersion';

  @override
  String get name => 'Tizen ' + _modelId;

  bool get usesSecureProtocol => getCapability('secure_protocol') == 'enabled';

  String get architecture {
    final String cpuArch = getCapability('cpu_arch');
    if (_emulatorArchs.contains(cpuArch)) {
      return cpuArch;
    } else if (usesSecureProtocol) {
      return cpuArch == 'armv7' ? 'arm' : 'arm64';
    } else {
      // Reading the cpu_arch capability value is not a reliable way to get the
      // runtime architecture from devices like Raspberry Pi. The following is a
      // little workaround.
      final String stdout =
          runSdbSync(<String>['shell', 'ls', '/usr/lib64']).stdout;
      return stdout.contains('No such file or directory') ? 'arm' : 'arm64';
    }
  }

  /// See: [AndroidDevice.isAppInstalled] in `android_device.dart`
  @override
  Future<bool> isAppInstalled(TizenTpk app, {String userIdentifier}) async {
    try {
      final List<String> command = usesSecureProtocol
          ? <String>['shell', '0', 'applist']
          : <String>['shell', 'app_launcher', '-l'];
      final RunResult result = await runSdbAsync(command);
      return result.stdout.contains("'${app.applicationId}'");
    } on Exception catch (error) {
      _logger.printError(error.toString());
      return false;
    }
  }

  Future<String> _getDeviceAppSignature(TizenTpk app) async {
    final List<String> rootCandidates = <String>[
      '/opt/usr/apps',
      '/opt/usr/globalapps',
    ];
    for (final String root in rootCandidates) {
      final File signatureFile = globals.fs.systemTempDirectory
          .createTempSync()
          .childFile('author-signature.xml');
      final RunResult result = await runSdbAsync(
        <String>[
          'pull',
          '$root/${app.id}/${signatureFile.basename}',
          signatureFile.path,
        ],
        checked: false,
      );
      if (result.exitCode == 0 && signatureFile.existsSync()) {
        final Signature signature = Signature.parseFromXml(signatureFile);
        return signature?.signatureValue;
      }
    }
    return null;
  }

  /// Source: [AndroidDevice.isLatestBuildInstalled] in `android_device.dart`
  @override
  Future<bool> isLatestBuildInstalled(TizenTpk app) async {
    final String installed = await _getDeviceAppSignature(app);
    return installed != null && installed == app.signature?.signatureValue;
  }

  /// Source: [AndroidDevice.installApp] in `android_device.dart`
  @override
  Future<bool> installApp(TizenTpk app, {String userIdentifier}) async {
    if (!app.file.existsSync()) {
      _logger.printError('"${relative(app.file.path)}" does not exist.');
      return false;
    }

    final double deviceVersion = double.tryParse(platformVersion) ?? 0;
    final double apiVersion = double.tryParse(app.manifest?.apiVersion) ?? 0;
    if (apiVersion > deviceVersion) {
      _logger.printStatus(
        'Warning: The package API version (${app.manifest?.apiVersion}) is greater than the device API version ($platformVersion).\n'
        'Check "tizen-manifest.xml" of your Tizen project to fix this problem.',
        color: TerminalColor.yellow,
      );
    }

    final Status status =
        _logger.startProgress('Installing ${relative(app.file.path)}...');
    final RunResult result =
        await runSdbAsync(<String>['install', app.file.path], checked: false);
    status.stop();

    if (result.exitCode != 0 ||
        result.stdout.contains('val[fail]') ||
        result.stdout.contains('install failed')) {
      _logger.printStatus(
        'Installing TPK failed with exit code ${result.exitCode}:\n$result',
      );
      return false;
    }

    if (usesSecureProtocol) {
      // It seems some post processing is done asynchronously after installing
      // an app. We need to put a short delay to avoid launch errors.
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return true;
  }

  /// Source: [AndroidDevice.uninstallApp] in `android_device.dart`
  @override
  Future<bool> uninstallApp(TizenTpk app, {String userIdentifier}) async {
    try {
      await runSdbAsync(<String>['uninstall', app.id]);
    } on Exception catch (error) {
      _logger.printError('sdb uninstall failed: $error');
      return false;
    }
    return true;
  }

  /// Source: [AndroidDevice._installLatestApp] in `android_device.dart`
  Future<bool> _installLatestApp(TizenTpk package) async {
    final bool wasInstalled = await isAppInstalled(package);
    if (wasInstalled) {
      if (await isLatestBuildInstalled(package)) {
        _logger.printStatus('Latest build already installed.');
        return true;
      }
    }
    _logger.printTrace('Installing TPK.');
    if (await installApp(package)) {
      // On TV emulator, a tpk must be installed twice if it's being installed
      // for the first time in order to prevent a library loading error.
      // Issue: https://github.com/flutter-tizen/flutter-tizen/issues/50
      if (!wasInstalled && usesSecureProtocol && await isLocalEmulator) {
        await installApp(package);
      }
    } else {
      _logger.printTrace('Warning: Failed to install TPK.');
      if (wasInstalled) {
        _logger.printStatus('Uninstalling old version...');
        if (!await uninstallApp(package)) {
          _logger.printError('Error: Uninstalling old version failed.');
          return false;
        }
        if (!await installApp(package)) {
          _logger.printError('Error: Failed to install TPK again.');
          return false;
        }
        return true;
      }
      return false;
    }
    return true;
  }

  /// Source: [AndroidDevice.startApp] in `android_device.dart`
  @override
  Future<LaunchResult> startApp(
    TizenTpk package, {
    String mainPath,
    String route,
    DebuggingOptions debuggingOptions,
    Map<String, dynamic> platformArgs,
    bool prebuiltApplication = false,
    bool ipv6 = false,
    String userIdentifier,
  }) async {
    if (!debuggingOptions.buildInfo.isDebug && await isLocalEmulator) {
      _logger.printError(
          'Profile and release builds are not supported on emulator targets.');
      return LaunchResult.failed();
    }

    // Build project if target application binary is not specified explicitly.
    if (!prebuiltApplication) {
      _logger.printTrace('Building TPK');
      final FlutterProject project = FlutterProject.current();
      await TizenBuilder.buildTpk(
        project: project,
        targetFile: mainPath,
        tizenBuildInfo: TizenBuildInfo(
          debuggingOptions.buildInfo,
          targetArch: architecture,
          deviceProfile: getCapability('profile_name'),
        ),
      );
      // Package has been built, so we can get the updated application id and
      // activity name from the tpk.
      package = await TizenTpk.fromTizenProject(project);
    }
    if (package == null) {
      throwToolExit('Problem building an application: see above error(s).');
    }

    _logger.printTrace("Stopping app '${package.name}' on $name.");
    if (await isAppInstalled(package)) {
      await stopApp(package, userIdentifier: userIdentifier);
    }

    if (!await _installLatestApp(package)) {
      return LaunchResult.failed();
    }

    final bool traceStartup = platformArgs['trace-startup'] as bool ?? false;
    _logger.printTrace('$this startApp');

    ProtocolDiscovery observatoryDiscovery;

    if (debuggingOptions.debuggingEnabled) {
      observatoryDiscovery = ProtocolDiscovery.observatory(
        await getLogReader(),
        portForwarder: portForwarder,
        hostPort: debuggingOptions.hostVmServicePort,
        devicePort: debuggingOptions.deviceVmServicePort,
        ipv6: ipv6,
        logger: _logger,
      );
    }

    final List<String> engineArgs = <String>[
      '--enable-dart-profiling',
      if (traceStartup) '--trace-startup',
      if (debuggingOptions.enableSoftwareRendering)
        '--enable-software-rendering',
      if (debuggingOptions.skiaDeterministicRendering)
        '--skia-deterministic-rendering',
      if (debuggingOptions.traceSkia) '--trace-skia',
      if (debuggingOptions.traceAllowlist != null) ...<String>[
        '--trace-allowlist',
        debuggingOptions.traceAllowlist,
      ],
      if (debuggingOptions.endlessTraceBuffer) '--endless-trace-buffer',
      if (debuggingOptions.dumpSkpOnShaderCompilation)
        '--dump-skp-on-shader-compilation',
      if (debuggingOptions.cacheSkSL) '--cache-sksl',
      if (debuggingOptions.debuggingEnabled) ...<String>[
        '--enable-checked-mode',
        if (debuggingOptions.startPaused) '--start-paused',
        if (debuggingOptions.disableServiceAuthCodes)
          '--disable-service-auth-codes',
        if (debuggingOptions.dartFlags.isNotEmpty) ...<String>[
          '--dart-flags',
          debuggingOptions.dartFlags,
        ],
        if (debuggingOptions.useTestFonts) '--use-test-fonts',
        if (debuggingOptions.verboseSystemLogs) '--verbose-logging',
      ],
    ];

    // Create a temp file to be consumed by a launching app.
    await _writeEngineArguments(engineArgs, '${package.applicationId}.rpm');

    final List<String> command = usesSecureProtocol
        ? <String>['shell', '0', 'execute', package.applicationId]
        : <String>['shell', 'app_launcher', '-s', package.applicationId];
    final String stdout = (await runSdbAsync(command)).stdout;
    if (!stdout.contains('successfully launched')) {
      _logger.printError(stdout.trim());
      return LaunchResult.failed();
    }

    if (!debuggingOptions.debuggingEnabled) {
      return LaunchResult.succeeded();
    }

    // Wait for the service protocol port here. This will complete once the
    // device has printed "Observatory is listening on...".
    _logger.printTrace('Waiting for observatory port to be available...');

    try {
      Uri observatoryUri;
      if (debuggingOptions.buildInfo.isDebug ||
          debuggingOptions.buildInfo.isProfile) {
        observatoryUri = await observatoryDiscovery.uri;
        if (observatoryUri == null) {
          _logger.printError(
            'Error waiting for a debug connection: '
            'The log reader stopped unexpectedly',
          );
          return LaunchResult.failed();
        }
      }
      return LaunchResult.succeeded(observatoryUri: observatoryUri);
    } on Exception catch (error) {
      _logger.printError('Error waiting for a debug connection: $error');
      return LaunchResult.failed();
    } finally {
      await observatoryDiscovery.cancel();
    }
  }

  Future<void> _writeEngineArguments(
    List<String> arguments,
    String filename,
  ) async {
    final File localFile =
        globals.fs.systemTempDirectory.createTempSync().childFile(filename);
    localFile.writeAsStringSync(arguments.join('\n'));
    final String remotePath = '/home/owner/share/tmp/sdk_tools/$filename';
    final RunResult result =
        await runSdbAsync(<String>['push', localFile.path, remotePath]);
    if (!result.stdout.contains('file(s) pushed')) {
      _logger.printError('Failed to push a file: $result');
    }
  }

  @override
  Future<bool> stopApp(TizenTpk app, {String userIdentifier}) async {
    if (app == null) {
      return false;
    }
    try {
      final List<String> command = usesSecureProtocol
          ? <String>['shell', '0', 'kill', app.applicationId]
          : <String>['shell', 'app_launcher', '-k', app.applicationId];
      final String stdout = (await runSdbAsync(command)).stdout;
      return stdout.contains('Kill appId') || stdout.contains('is Terminated');
    } on Exception catch (error) {
      _logger.printError(error.toString());
      return false;
    }
  }

  DateTime get currentDeviceTime {
    try {
      final RunResult result = runSdbSync(usesSecureProtocol
          ? <String>['shell', '0', 'getdate']
          : <String>['shell', 'date', '+""%Y-%m-%d %H:%M:%S""']);
      // Notice that the result isn't normalized with the actual device time
      // zone. (Because the %z info is missing from the `getdate` result.)
      // Using the UTC format (appending 'Z' at the end) just prevents the
      // result from being affected by the host's time zone.
      return DateTime.parse('${result.stdout.trim()}Z');
    } on FormatException catch (error) {
      _logger.printError(error.toString());
      return null;
    } on Exception catch (error) {
      _logger.printError('Failed to get device time: $error');
      return null;
    }
  }

  DateTime _lastClearLogTime;

  @override
  void clearLogs() {
    // `sdb dlog -c` is not allowed for non-root users.
    _lastClearLogTime = currentDeviceTime;
  }

  /// Source: [AndroidDevice.getLogReader] in `android_device.dart`
  @override
  FutureOr<DeviceLogReader> getLogReader({
    TizenTpk app,
    bool includePastLogs = false,
  }) async =>
      _logReader ??= await TizenDlogReader.createLogReader(
        this,
        _processManager,
        after: includePastLogs ? _lastClearLogTime : currentDeviceTime,
      );

  @override
  DevicePortForwarder get portForwarder =>
      _portForwarder ??= TizenDevicePortForwarder(
        device: this,
        logger: _logger,
      );

  @override
  bool isSupported() {
    final double deviceVersion = double.tryParse(platformVersion) ?? 0;
    if (!_emulatorArchs.contains(getCapability('cpu_arch')) &&
        usesSecureProtocol &&
        deviceVersion < 6.0) {
      return false;
    }
    return deviceVersion >= 4.0;
  }

  @override
  bool get supportsScreenshot => false;

  @override
  bool isSupportedForProject(FlutterProject flutterProject) {
    return flutterProject.isModule &&
        flutterProject.directory.childDirectory('tizen').existsSync();
  }

  /// Source: [AndroidDevice.dispose] in `android_device.dart`
  @override
  Future<void> dispose() async {
    _logReader?._stop();
    await _portForwarder?.dispose();
  }
}

/// A log reader that reads from `sdb dlog`.
///
/// Source: [AdbLogReader] in `android_device.dart`
class TizenDlogReader extends DeviceLogReader {
  TizenDlogReader._(this.name, this._device, this._sdbProcess, this._after) {
    _linesController = StreamController<String>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  static Future<TizenDlogReader> createLogReader(
    TizenDevice device,
    ProcessManager processManager, {
    DateTime after,
  }) async {
    // `sdb dlog -m` is not allowed for non-root users.
    final List<String> args = device.usesSecureProtocol
        ? <String>['shell', '0', 'showlog_level', 'time']
        : <String>['dlog', '-v', 'time', 'ConsoleMessage'];

    final Process process = await processManager.start(device.sdbCommand(args));

    return TizenDlogReader._(device.name, device, process, after);
  }

  final TizenDevice _device;
  final Process _sdbProcess;
  final DateTime _after;

  @override
  final String name;

  StreamController<String> _linesController;

  @override
  Stream<String> get logLines => _linesController.stream;

  void _start() {
    const Utf8Decoder decoder = Utf8Decoder(reportErrors: false);
    _sdbProcess.stdout
        .transform<String>(decoder)
        .transform<String>(const LineSplitter())
        .listen(_onLine);
    _sdbProcess.stderr
        .transform<String>(decoder)
        .transform<String>(const LineSplitter())
        .listen(_onLine);
    unawaited(_sdbProcess.exitCode.whenComplete(() {
      if (_linesController.hasListener) {
        _linesController.close();
      }
    }));
  }

  // '00-00 00:00:00.000+0000 '
  final RegExp _timeFormat =
      RegExp(r'(\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})\.\d{3}[+-]\d{4}\s');

  // 'I/ConsoleMessage(  PID): '
  final RegExp _logFormat = RegExp(r'[IWEF]\/.+?\(\s*(\d+)\):\s');

  static const List<String> _filteredTexts = <String>[
    // Issue: https://github.com/flutter-tizen/engine/issues/91
    'xkbcommon: ERROR:',
    'couldn\'t find a Compose file for locale',
  ];

  bool _acceptedLastLine = true;

  void _onLine(String line) {
    // This line might be processed after the subscription is closed but before
    // sdb stops streaming logs.
    if (_linesController.isClosed) {
      return;
    }

    final Match timeMatch = _timeFormat.firstMatch(line);
    if (timeMatch != null) {
      // Chop off the time.
      line = line.replaceFirst(timeMatch.group(0), '');

      final Match logMatch = _logFormat.firstMatch(line);
      if (logMatch != null) {
        if (appPid != null && int.parse(logMatch.group(1)) != appPid) {
          _acceptedLastLine = false;
          return;
        } else if (_after != null && !_device.usesSecureProtocol) {
          // TODO(swift-kim): Deal with invalid timestamps on TV devices.
          final DateTime logTime =
              DateTime.tryParse('${_after.year}-${timeMatch.group(1)}Z');
          if (logTime?.isBefore(_after) ?? false) {
            _acceptedLastLine = false;
            return;
          }
        }
        if (_filteredTexts.any((String text) => line.contains(text))) {
          _acceptedLastLine = false;
          return;
        }
        _acceptedLastLine = true;
        _linesController.add(line);
      } else {
        _acceptedLastLine = false;
      }
    } else if (line.startsWith('Buffer main is set') ||
        line.startsWith('ioctl LOGGER') ||
        line.startsWith('argc = 4, optind = 3') ||
        line.startsWith('--------- beginning of')) {
      _acceptedLastLine = false;
    } else if (_acceptedLastLine) {
      // If it doesn't match the log pattern at all, then pass it through if we
      // passed the last matching line through. It might be a multiline message.
      _linesController.add(line);
    }
  }

  void _stop() {
    _linesController.close();
    _sdbProcess?.kill();
  }

  @override
  void dispose() {
    _stop();
  }
}

/// A [DevicePortForwarder] implemented for Tizen devices.
///
/// Source: [AndroidDevicePortForwarder] in `android_device.dart`
class TizenDevicePortForwarder extends DevicePortForwarder {
  TizenDevicePortForwarder({
    @required TizenDevice device,
    @required Logger logger,
  })  : _device = device,
        _logger = logger;

  final TizenDevice _device;
  final Logger _logger;

  static int _extractPort(String portString) {
    return int.tryParse(portString.trim().split(':')[1]);
  }

  @override
  List<ForwardedPort> get forwardedPorts {
    final List<ForwardedPort> ports = <ForwardedPort>[];

    String stdout;
    try {
      final RunResult result =
          _device.runSdbSync(<String>['forward', '--list']);
      stdout = result.stdout.trim();
    } on ProcessException catch (error) {
      _logger.printError('Failed to list forwarded ports: $error.');
      return ports;
    }

    for (final String line in LineSplitter.split(stdout)) {
      if (!line.startsWith(_device.id)) {
        continue;
      }
      final List<String> splitLine = line.split(RegExp(r'\s+'));
      if (splitLine.length != 3) {
        continue;
      }

      // Attempt to extract ports.
      final int hostPort = _extractPort(splitLine[1]);
      final int devicePort = _extractPort(splitLine[2]);

      // Failed, skip.
      if (hostPort == null || devicePort == null) {
        continue;
      }

      ports.add(ForwardedPort(hostPort, devicePort));
    }

    return ports;
  }

  @override
  Future<int> forward(int devicePort, {int hostPort}) async {
    hostPort ??= await globals.os.findFreePort(ipv6: false);
    if (hostPort == 0) {
      throwToolExit('No available port could be found on the host.');
    }

    final RunResult result = await _device.runSdbAsync(
      <String>['forward', 'tcp:$hostPort', 'tcp:$devicePort'],
      checked: false,
    );
    if (result.stderr.isNotEmpty) {
      result.throwException('sdb returned error:\n${result.stderr}');
    }
    if (result.exitCode != 0) {
      if (result.stdout.isNotEmpty) {
        result.throwException('sdb returned error:\n${result.stdout}');
      }
      result.throwException('sdb failed without a message.');
    }

    return hostPort;
  }

  @override
  Future<void> unforward(ForwardedPort forwardedPort) async {
    final RunResult result = await _device.runSdbAsync(
      <String>['forward', '--remove', 'tcp:${forwardedPort.hostPort}'],
      checked: false,
    );
    // The port may have already been unforwarded, for example if there
    // are multiple attach process already connected.
    if (result.stderr.isEmpty ||
        result.stderr.contains('error: cannot remove forward listener')) {
      return;
    }
    result.throwException('Process exited abnormally:\n$result');
  }

  @override
  Future<void> dispose() async {
    for (final ForwardedPort port in forwardedPorts) {
      await unforward(port);
    }
  }
}
