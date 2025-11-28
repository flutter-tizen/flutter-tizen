// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/ios/devices.dart';
import 'package:flutter_tools/src/runner/target_devices.dart';
import 'package:meta/meta.dart';

import 'tizen_device.dart';

const _checkingForWirelessDevicesMessage = 'Checking for wireless devices...';
const _chooseOneMessage = 'Please choose one (or "q" to quit)';
const _connectedDevicesMessage = 'Connected devices:';
const _foundButUnsupportedDevicesMessage =
    'The following devices were found, but are not supported by this project:';
const _noAttachedCheckForWirelessMessage = 'No devices found yet. Checking for wireless devices...';
const _noDevicesFoundMessage = 'No devices found.';
const _noWirelessDevicesFoundMessage = 'No wireless devices were found.';
const _wirelesslyConnectedDevicesMessage = 'Wirelessly connected devices:';

String _chooseDeviceOptionMessage(int option, String name, String deviceId) =>
    '[$option]: $name ($deviceId)';
String _foundMultipleSpecifiedDevicesMessage(String deviceId) =>
    'Found multiple devices with name or id matching $deviceId:';
String _foundSpecifiedDevicesMessage(int count, String deviceId) =>
    'Found $count devices with name or id matching $deviceId:';
String _noMatchingDeviceMessage(String deviceId) => 'No supported devices found with name or id '
    "matching '$deviceId'.";
String flutterSpecifiedDeviceDevModeDisabled(String deviceName) => 'To use '
    "'$deviceName' for development, enable Developer Mode in Settings → Privacy & Security on the device. "
    'If this does not work, open Xcode, reconnect the device, and look for a '
    'popup on the device asking you to trust this computer.';
String flutterSpecifiedDeviceUnpaired(String deviceName) => "'$deviceName' is not paired. "
    'Open Xcode and trust this computer when prompted.';

/// A class that handles finding and selecting target devices.
///
/// Source: [TargetDevices] in `flutter_tools/lib/src/runner/target_devices.dart`
class TizenTargetDevices implements TargetDevices {
  /// Source: [TargetDevices._private] in `target_devices.dart`
  TizenTargetDevices({
    required DeviceManager deviceManager,
    required Logger logger,
    required this.deviceConnectionInterface,
  })  : _deviceManager = deviceManager,
        _logger = logger;

  final DeviceManager _deviceManager;
  final Logger _logger;
  @override
  final DeviceConnectionInterface? deviceConnectionInterface;

  /// Source: [TargetDevices._includeAttachedDevices] in `target_devices.dart`
  bool get _includeAttachedDevices =>
      deviceConnectionInterface == null ||
      deviceConnectionInterface == DeviceConnectionInterface.attached;

  /// Source: [TargetDevices._includeWirelessDevices] in `target_devices.dart`
  bool get _includeWirelessDevices =>
      deviceConnectionInterface == null ||
      deviceConnectionInterface == DeviceConnectionInterface.wireless;

  /// Source: [TargetDevices._getAttachedDevices] in `target_devices.dart`
  Future<List<Device>> _getAttachedDevices({DeviceDiscoverySupportFilter? supportFilter}) async {
    if (!_includeAttachedDevices) {
      return <Device>[];
    }
    return _deviceManager.getDevices(
      filter: DeviceDiscoveryFilter(
        deviceConnectionInterface: DeviceConnectionInterface.attached,
        supportFilter: supportFilter,
      ),
    );
  }

  /// Source: [TargetDevices._getWirelessDevices] in `target_devices.dart`
  Future<List<Device>> _getWirelessDevices({DeviceDiscoverySupportFilter? supportFilter}) async {
    if (!_includeWirelessDevices) {
      return <Device>[];
    }
    return _deviceManager.getDevices(
      filter: DeviceDiscoveryFilter(
        deviceConnectionInterface: DeviceConnectionInterface.wireless,
        supportFilter: supportFilter,
      ),
    );
  }

  /// Source: [TargetDevices._getDeviceById] in `target_devices.dart`
  Future<List<Device>> _getDeviceById({
    bool includeDevicesUnsupportedByProject = false,
    bool includeDisconnected = false,
  }) async {
    return _deviceManager.getDevices(
      filter: DeviceDiscoveryFilter(
        excludeDisconnected: !includeDisconnected,
        supportFilter: _deviceManager.deviceSupportFilter(
          includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
        ),
        deviceConnectionInterface: deviceConnectionInterface,
      ),
    );
  }

  /// Source: [TargetDevices._defaultSupportFilter] in `target_devices.dart`
  DeviceDiscoverySupportFilter _defaultSupportFilter(bool includeDevicesUnsupportedByProject) {
    return _deviceManager.deviceSupportFilter(
      includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
    );
  }

  /// Source: [TargetDevices.startExtendedWirelessDeviceDiscovery] in `target_devices.dart`
  @override
  void startExtendedWirelessDeviceDiscovery({Duration? deviceDiscoveryTimeout}) {}

  /// Source: [TargetDevices.findAllTargetDevices] in `target_devices.dart`
  @override
  Future<List<Device>?> findAllTargetDevices({
    Duration? deviceDiscoveryTimeout,
    bool includeDevicesUnsupportedByProject = false,
  }) async {
    if (!globals.doctor!.canLaunchAnything) {
      _logger.printError(globals.userMessages.flutterNoDevelopmentDevice);
      return null;
    }

    if (deviceDiscoveryTimeout != null) {
      // Reset the cache with the specified timeout.
      await _deviceManager.refreshAllDevices(timeout: deviceDiscoveryTimeout);
    }

    if (_deviceManager.hasSpecifiedDeviceId) {
      // Must check for device match separately from `_getAttachedDevices` and
      // `_getWirelessDevices` because if an exact match is found in one
      // and a partial match is found in another, there is no way to distinguish
      // between them.
      final List<Device> devices = await _getDeviceById(
        includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
      );
      if (devices.length == 1) {
        return devices;
      }
    }

    final List<Device> attachedDevices = await _getAttachedDevices(
      supportFilter: _defaultSupportFilter(includeDevicesUnsupportedByProject),
    );
    final List<Device> wirelessDevices = await _getWirelessDevices(
      supportFilter: _defaultSupportFilter(includeDevicesUnsupportedByProject),
    );
    final List<Device> allDevices = attachedDevices + wirelessDevices;

    if (allDevices.isEmpty) {
      return _handleNoDevices();
    } else if (_deviceManager.hasSpecifiedAllDevices) {
      return allDevices;
    } else if (allDevices.length > 1) {
      return _handleMultipleDevices(attachedDevices, wirelessDevices);
    }
    return allDevices;
  }

  /// Source: [TargetDevices._handleNoDevices] in `target_devices.dart`
  Future<List<Device>?> _handleNoDevices() async {
    // Get connected devices from cache, including unsupported ones.
    final List<Device> unsupportedDevices = await _deviceManager.getAllDevices(
      filter: DeviceDiscoveryFilter(deviceConnectionInterface: deviceConnectionInterface),
    );

    if (_deviceManager.hasSpecifiedDeviceId) {
      _logger.printStatus(_noMatchingDeviceMessage(_deviceManager.specifiedDeviceId!));
      if (unsupportedDevices.isNotEmpty) {
        _logger.printStatus('');
        _logger.printStatus('The following devices were found:');
        await TizenDevice.printDevices(unsupportedDevices, _logger);
      }
      return null;
    }

    _logger.printStatus(
      _deviceManager.hasSpecifiedAllDevices
          ? _noDevicesFoundMessage
          : globals.userMessages.flutterNoSupportedDevices,
    );
    await _printUnsupportedDevice(unsupportedDevices);
    return null;
  }

  /// Source: [TargetDevices._handleMultipleDevices] in `target_devices.dart`
  Future<List<Device>?> _handleMultipleDevices(
    List<Device> attachedDevices,
    List<Device> wirelessDevices,
  ) async {
    final List<Device> allDevices = attachedDevices + wirelessDevices;

    final Device? ephemeralDevice = _deviceManager.getSingleEphemeralDevice(allDevices);
    if (ephemeralDevice != null) {
      return <Device>[ephemeralDevice];
    }

    if (globals.terminal.stdinHasTerminal) {
      return _selectFromMultipleDevices(attachedDevices, wirelessDevices);
    } else {
      return _printMultipleDevices(attachedDevices, wirelessDevices);
    }
  }

  /// Source: [TargetDevices._printMultipleDevices] in `target_devices.dart`
  Future<List<Device>?> _printMultipleDevices(
    List<Device> attachedDevices,
    List<Device> wirelessDevices,
  ) async {
    var supportedAttachedDevices = attachedDevices;
    var supportedWirelessDevices = wirelessDevices;
    if (_deviceManager.hasSpecifiedDeviceId) {
      final int allDeviceLength = supportedAttachedDevices.length + supportedWirelessDevices.length;
      _logger.printStatus(
        _foundSpecifiedDevicesMessage(allDeviceLength, _deviceManager.specifiedDeviceId!),
      );
    } else {
      // Get connected devices from cache, including ones unsupported for the
      // project but still supported by Flutter.
      supportedAttachedDevices = await _getAttachedDevices(
        supportFilter: DeviceDiscoverySupportFilter.excludeDevicesUnsupportedByFlutter(),
      );
      supportedWirelessDevices = await _getWirelessDevices(
        supportFilter: DeviceDiscoverySupportFilter.excludeDevicesUnsupportedByFlutter(),
      );

      _logger.printStatus(globals.userMessages.flutterSpecifyDeviceWithAllOption);
      _logger.printStatus('');
    }

    await TizenDevice.printDevices(supportedAttachedDevices, _logger);

    if (supportedWirelessDevices.isNotEmpty) {
      if (_deviceManager.hasSpecifiedDeviceId || supportedAttachedDevices.isNotEmpty) {
        _logger.printStatus('');
      }
      _logger.printStatus(_wirelesslyConnectedDevicesMessage);
      await TizenDevice.printDevices(supportedWirelessDevices, _logger);
    }

    return null;
  }

  /// Source: [TargetDevices._selectFromMultipleDevices] in `target_devices.dart`
  Future<List<Device>?> _selectFromMultipleDevices(
    List<Device> attachedDevices,
    List<Device> wirelessDevices,
  ) async {
    final List<Device> allDevices = attachedDevices + wirelessDevices;

    if (_deviceManager.hasSpecifiedDeviceId) {
      _logger.printStatus(
        _foundSpecifiedDevicesMessage(allDevices.length, _deviceManager.specifiedDeviceId!),
      );
    } else {
      _logger.printStatus(_connectedDevicesMessage);
    }

    await TizenDevice.printDevices(attachedDevices, _logger);

    if (wirelessDevices.isNotEmpty) {
      _logger.printStatus('');
      _logger.printStatus(_wirelesslyConnectedDevicesMessage);
      await TizenDevice.printDevices(wirelessDevices, _logger);
      _logger.printStatus('');
    }

    final Device chosenDevice = await _chooseOneOfAvailableDevices(allDevices);

    // Update the [DeviceManager.specifiedDeviceId] so that the user will not
    // be prompted again.
    _deviceManager.specifiedDeviceId = chosenDevice.id;

    return <Device>[chosenDevice];
  }

  /// Source: [TargetDevices._printUnsupportedDevice] in `target_devices.dart`
  Future<void> _printUnsupportedDevice(List<Device> unsupportedDevices) async {
    if (unsupportedDevices.isNotEmpty) {
      final result = StringBuffer();
      result.writeln();
      result.writeln(_foundButUnsupportedDevicesMessage);
      result.writeAll(
        (await Device.descriptions(unsupportedDevices)).map((String desc) => desc).toList(),
        '\n',
      );
      result.writeln();
      result.writeln(
        globals.userMessages.flutterMissPlatformProjects(
          Device.devicesPlatformTypes(unsupportedDevices),
        ),
      );
      _logger.printStatus(result.toString(), newline: false);
    }
  }

  /// Source: [TargetDevices._chooseOneOfAvailableDevices] in `target_devices.dart`
  Future<Device> _chooseOneOfAvailableDevices(List<Device> devices) async {
    _displayDeviceOptions(devices);
    final String userInput = await _readUserInput(devices.length);
    if (userInput.toLowerCase() == 'q') {
      throwToolExit('');
    }
    return devices[int.parse(userInput) - 1];
  }

  /// Source: [TargetDevices._displayDeviceOptions] in `target_devices.dart`
  void _displayDeviceOptions(List<Device> devices) {
    var count = 1;
    for (final device in devices) {
      _logger.printStatus(_chooseDeviceOptionMessage(count, device.displayName, device.id));
      count++;
    }
  }

  /// Source: [TargetDevices._readUserInput] in `target_devices.dart`
  Future<String> _readUserInput(int deviceCount) async {
    globals.terminal.usesTerminalUi = true;
    final String result = await globals.terminal.promptForCharInput(
      <String>[for (int i = 0; i < deviceCount; i++) '${i + 1}', 'q', 'Q'],
      displayAcceptedCharacters: false,
      logger: _logger,
      prompt: _chooseOneMessage,
    );
    return result;
  }
}

/// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery] in `target_devices.dart`
abstract class TargetDevicesWithExtendedWirelessDeviceDiscoveryBase extends TizenTargetDevices {
  TargetDevicesWithExtendedWirelessDeviceDiscoveryBase({
    required super.deviceManager,
    required super.logger,
    super.deviceConnectionInterface,
  });

  Future<void>? _wirelessDevicesRefresh;

  @visibleForTesting
  var waitForWirelessBeforeInput = false;

  @visibleForTesting
  late final deviceSelection = TargetDeviceSelectionBase(_logger);

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery.startExtendedWirelessDeviceDiscovery] in `target_devices.dart`
  @override
  void startExtendedWirelessDeviceDiscovery({Duration? deviceDiscoveryTimeout}) {
    if (deviceDiscoveryTimeout == null && _includeWirelessDevices) {
      _wirelessDevicesRefresh ??= _deviceManager.refreshExtendedWirelessDeviceDiscoverers(
        timeout: DeviceManager.minimumWirelessDeviceDiscoveryTimeout,
      );
    }
    return;
  }

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery._getRefreshedWirelessDevices] in `target_devices.dart`
  Future<List<Device>> _getRefreshedWirelessDevices({
    bool includeDevicesUnsupportedByProject = false,
  }) async {
    if (!_includeWirelessDevices) {
      return <Device>[];
    }
    startExtendedWirelessDeviceDiscovery();
    return () async {
      await _wirelessDevicesRefresh;
      return _deviceManager.getDevices(
        filter: DeviceDiscoveryFilter(
          deviceConnectionInterface: DeviceConnectionInterface.wireless,
          supportFilter: _defaultSupportFilter(includeDevicesUnsupportedByProject),
        ),
      );
    }();
  }

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery._waitForIOSDeviceToConnect] in `target_devices.dart`
  Future<Device?> _waitForIOSDeviceToConnect(IOSDevice device) async {
    for (final DeviceDiscovery discoverer in _deviceManager.deviceDiscoverers) {
      if (discoverer is IOSDevices) {
        _logger.printStatus('Waiting for ${device.displayName} to connect...');
        final Status waitingStatus = _logger.startSpinner(
          timeout: const Duration(seconds: 30),
          warningColor: TerminalColor.red,
          slowWarningCallback: () {
            return 'The device was unable to connect after 30 seconds. Ensure the device is paired and unlocked.';
          },
        );
        final Device? connectedDevice = await discoverer.waitForDeviceToConnect(device, _logger);
        waitingStatus.stop();
        return connectedDevice;
      }
    }
    return null;
  }

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery.findAllTargetDevices] in `target_devices.dart`
  @override
  Future<List<Device>?> findAllTargetDevices({
    Duration? deviceDiscoveryTimeout,
    bool includeDevicesUnsupportedByProject = false,
  }) async {
    if (!globals.doctor!.canLaunchAnything) {
      _logger.printError(globals.userMessages.flutterNoDevelopmentDevice);
      return null;
    }

    // When a user defines the timeout or filters to only attached devices,
    // use the super function that does not do longer wireless device
    // discovery and does not wait for devices to connect.
    if (deviceDiscoveryTimeout != null ||
        deviceConnectionInterface == DeviceConnectionInterface.attached) {
      return super.findAllTargetDevices(
        deviceDiscoveryTimeout: deviceDiscoveryTimeout,
        includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
      );
    }

    // Start polling for wireless devices that need longer to load if it hasn't
    // already been started.
    startExtendedWirelessDeviceDiscovery();

    if (_deviceManager.hasSpecifiedDeviceId) {
      // Get devices matching the specified device regardless of whether they
      // are currently connected or not.
      // If there is a single matching connected device, return it immediately.
      // If the only device found is an iOS device that is not connected yet,
      // wait for it to connect.
      // If there are multiple matches, continue on to wait for all attached
      // and wireless devices to load so the user can select between all
      // connected matches.
      final List<Device> specifiedDevices = await _getDeviceById(
        includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
        includeDisconnected: true,
      );

      if (specifiedDevices.length == 1) {
        Device? matchedDevice = specifiedDevices.first;
        if (matchedDevice is IOSDevice) {
          // If the only matching device is not paired, print a warning
          if (!matchedDevice.isPaired) {
            _logger.printStatus(flutterSpecifiedDeviceUnpaired(matchedDevice.displayName));
            return null;
          }
          // If the only matching device does not have Developer Mode enabled,
          // print a warning
          if (!matchedDevice.devModeEnabled) {
            _logger.printStatus(flutterSpecifiedDeviceDevModeDisabled(matchedDevice.displayName));
            return null;
          }

          if (!matchedDevice.isConnected) {
            matchedDevice = await _waitForIOSDeviceToConnect(matchedDevice);
          }
        }

        if (matchedDevice != null && matchedDevice.isConnected) {
          return <Device>[matchedDevice];
        }
      } else {
        for (final IOSDevice device in specifiedDevices.whereType<IOSDevice>()) {
          // Print warning for every matching unpaired device.
          if (!device.isPaired) {
            _logger.printStatus(flutterSpecifiedDeviceUnpaired(device.displayName));
          }

          // Print warning for every matching device that does not have Developer Mode enabled.
          if (!device.devModeEnabled) {
            _logger.printStatus(flutterSpecifiedDeviceDevModeDisabled(device.displayName));
          }
        }
      }
    }

    final List<Device> attachedDevices = await _getAttachedDevices(
      supportFilter: _defaultSupportFilter(includeDevicesUnsupportedByProject),
    );

    // _getRefreshedWirelessDevices must be run after _getAttachedDevices is
    // finished to prevent non-iOS discoverers from running simultaneously.
    // `AndroidDevices` may error if run simultaneously.
    final Future<List<Device>> futureWirelessDevices = _getRefreshedWirelessDevices(
      includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
    );

    if (attachedDevices.isEmpty) {
      return _handleNoAttachedDevices(attachedDevices, futureWirelessDevices);
    } else if (_deviceManager.hasSpecifiedAllDevices) {
      return _handleAllDevices(attachedDevices, futureWirelessDevices);
    }
    // Even if there's only a single attached device, continue to
    // `_handleRemainingDevices` since there might be wireless devices
    // that are not loaded yet.
    return _handleRemainingDevices(attachedDevices, futureWirelessDevices);
  }

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery._handleNoAttachedDevices] in `target_devices.dart`
  Future<List<Device>?> _handleNoAttachedDevices(
    List<Device> attachedDevices,
    Future<List<Device>> futureWirelessDevices,
  ) async {
    if (_includeAttachedDevices) {
      _logger.printStatus(_noAttachedCheckForWirelessMessage);
    } else {
      _logger.printStatus(_checkingForWirelessDevicesMessage);
    }

    final List<Device> wirelessDevices = await futureWirelessDevices;
    final List<Device> allDevices = attachedDevices + wirelessDevices;

    if (allDevices.isEmpty) {
      _logger.printStatus('');
      return _handleNoDevices();
    } else if (_deviceManager.hasSpecifiedAllDevices) {
      return allDevices;
    } else if (allDevices.length > 1) {
      _logger.printStatus('');
      return _handleMultipleDevices(attachedDevices, wirelessDevices);
    }
    return allDevices;
  }

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery._handleAllDevices] in `target_devices.dart`
  Future<List<Device>?> _handleAllDevices(
    List<Device> devices,
    Future<List<Device>> futureWirelessDevices,
  ) async {
    _logger.printStatus(_checkingForWirelessDevicesMessage);
    final List<Device> wirelessDevices = await futureWirelessDevices;
    return devices + wirelessDevices;
  }

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery._handleRemainingDevices] in `target_devices.dart`
  Future<List<Device>?> _handleRemainingDevices(
    List<Device> attachedDevices,
    Future<List<Device>> futureWirelessDevices,
  ) async {
    final Device? ephemeralDevice = _deviceManager.getSingleEphemeralDevice(attachedDevices);
    if (ephemeralDevice != null) {
      return <Device>[ephemeralDevice];
    }

    if (!globals.terminal.stdinHasTerminal || !_logger.supportsColor) {
      _logger.printStatus(_checkingForWirelessDevicesMessage);
      final List<Device> wirelessDevices = await futureWirelessDevices;
      if (attachedDevices.length + wirelessDevices.length == 1) {
        return attachedDevices + wirelessDevices;
      }
      _logger.printStatus('');
      // If the terminal has stdin but does not support color/ANSI (which is
      // needed to clear lines), fallback to standard selection of device.
      if (globals.terminal.stdinHasTerminal && !_logger.supportsColor) {
        return _handleMultipleDevices(attachedDevices, wirelessDevices);
      }
      // If terminal does not have stdin, print out device list.
      return _printMultipleDevices(attachedDevices, wirelessDevices);
    }

    return _selectFromDevicesAndCheckForWireless(attachedDevices, futureWirelessDevices);
  }

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery._selectFromDevicesAndCheckForWireless] in `target_devices.dart`
  Future<List<Device>?> _selectFromDevicesAndCheckForWireless(
    List<Device> attachedDevices,
    Future<List<Device>> futureWirelessDevices,
  ) async {
    if (attachedDevices.length == 1 || !_deviceManager.hasSpecifiedDeviceId) {
      _logger.printStatus(_connectedDevicesMessage);
    } else if (_deviceManager.hasSpecifiedDeviceId) {
      // Multiple devices were found with part of the name/id provided.
      _logger.printStatus(_foundMultipleSpecifiedDevicesMessage(_deviceManager.specifiedDeviceId!));
    }

    // Display list of attached devices.
    await TizenDevice.printDevices(attachedDevices, _logger);

    // Display waiting message.
    _logger.printStatus('');
    _logger.printStatus(_checkingForWirelessDevicesMessage);
    _logger.printStatus('');

    // Start user device selection so user can select device while waiting
    // for wireless devices to load if they want.
    _displayDeviceOptions(attachedDevices);
    deviceSelection.devices = attachedDevices;
    final Future<Device> futureChosenDevice = deviceSelection.userSelectDevice();
    Device? chosenDevice;

    // Once wireless devices are found, we clear out the waiting message (3),
    // device option list (attachedDevices.length), and device option prompt (1).
    int numLinesToClear = attachedDevices.length + 4;

    futureWirelessDevices = futureWirelessDevices.then((List<Device> wirelessDevices) async {
      // If device is already chosen, don't update terminal with
      // wireless device list.
      if (chosenDevice != null) {
        return wirelessDevices;
      }

      final List<Device> allDevices = attachedDevices + wirelessDevices;

      if (_logger.isVerbose) {
        await _verbosePrintWirelessDevices(attachedDevices, wirelessDevices);
      } else {
        // Also clear any invalid device selections.
        numLinesToClear += deviceSelection.invalidAttempts;
        await _printWirelessDevices(wirelessDevices, numLinesToClear);
      }
      _logger.printStatus('');

      // Reprint device option list.
      _displayDeviceOptions(allDevices);
      deviceSelection.devices = allDevices;
      // Reprint device option prompt.
      _logger.printStatus('$_chooseOneMessage: ', emphasis: true, newline: false);
      return wirelessDevices;
    });

    // Used for testing.
    if (waitForWirelessBeforeInput) {
      await futureWirelessDevices;
    }

    // Wait for user to select a device.
    chosenDevice = await futureChosenDevice;

    // Update the [DeviceManager.specifiedDeviceId] so that the user will not
    // be prompted again.
    _deviceManager.specifiedDeviceId = chosenDevice.id;

    return <Device>[chosenDevice];
  }

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery._verbosePrintWirelessDevices] in `target_devices.dart`
  Future<void> _verbosePrintWirelessDevices(
    List<Device> attachedDevices,
    List<Device> wirelessDevices,
  ) async {
    if (wirelessDevices.isEmpty) {
      _logger.printStatus(_noWirelessDevicesFoundMessage);
    }
    // The iOS xcdevice outputs once wireless devices are done loading, so
    // reprint attached devices so they're grouped with the wireless ones.
    _logger.printStatus(_connectedDevicesMessage);
    await TizenDevice.printDevices(attachedDevices, _logger);

    if (wirelessDevices.isNotEmpty) {
      _logger.printStatus('');
      _logger.printStatus(_wirelesslyConnectedDevicesMessage);
      await TizenDevice.printDevices(wirelessDevices, _logger);
    }
  }

  /// Source: [TargetDevicesWithExtendedWirelessDeviceDiscovery._printWirelessDevices] in `target_devices.dart`
  Future<void> _printWirelessDevices(List<Device> wirelessDevices, int numLinesToClear) async {
    _logger.printStatus(globals.terminal.clearLines(numLinesToClear), newline: false);
    _logger.printStatus('');
    if (wirelessDevices.isEmpty) {
      _logger.printStatus(_noWirelessDevicesFoundMessage);
    } else {
      _logger.printStatus(_wirelesslyConnectedDevicesMessage);
      await TizenDevice.printDevices(wirelessDevices, _logger);
    }
  }
}

/// Source: [TargetDeviceSelection] in `target_devices.dart`
class TargetDeviceSelectionBase {
  TargetDeviceSelectionBase(this._logger);

  var devices = <Device>[];
  final Logger _logger;
  var invalidAttempts = 0;

  /// Source: [TargetDeviceSelection.userSelectDevice] in `target_devices.dart`
  Future<Device> userSelectDevice() async {
    Device? chosenDevice;
    while (chosenDevice == null) {
      final String userInputString = await readUserInput();
      if (userInputString.toLowerCase() == 'q') {
        throwToolExit('');
      }
      final int deviceIndex = int.parse(userInputString) - 1;
      if (deviceIndex > -1 && deviceIndex < devices.length) {
        chosenDevice = devices[deviceIndex];
      }
    }

    return chosenDevice;
  }

  /// Source: [TargetDeviceSelection.readUserInput] in `target_devices.dart`
  @visibleForTesting
  Future<String> readUserInput() async {
    final pattern = RegExp(r'\d+$|q', caseSensitive: false);
    String? choice;
    globals.terminal.singleCharMode = true;
    while (choice == null || choice.length > 1 || !pattern.hasMatch(choice)) {
      _logger.printStatus(_chooseOneMessage, emphasis: true, newline: false);
      // prompt ends with ': '
      _logger.printStatus(': ', emphasis: true, newline: false);
      choice = (await globals.terminal.keystrokes.first).trim();
      _logger.printStatus(choice);
      invalidAttempts++;
    }
    globals.terminal.singleCharMode = false;
    return choice;
  }
}
