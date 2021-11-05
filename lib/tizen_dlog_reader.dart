// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_tools/src/android/android_device.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'tizen_device.dart';

/// A log reader that reads from `sdb dlog`.
///
/// Source: [AdbLogReader] in `android_device.dart`
class TizenDlogReader extends DeviceLogReader {
  TizenDlogReader._(
    this.name,
    this._device,
    this._sdbProcess,
    this._after,
  ) : assert(_after != null) {
    _linesController = StreamController<String>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  static Future<TizenDlogReader> createLogReader(
    TizenDevice device,
    ProcessManager processManager, {
    @required DateTime after,
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
    "couldn't find a Compose file for locale",
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
        } else if (!_device.usesSecureProtocol) {
          // TODO(swift-kim): Deal with invalid timestamps on TV devices.
          final DateTime logTime =
              DateTime.tryParse('${_after.year}-${timeMatch.group(1)}Z');
          if (logTime != null && logTime.isBefore(_after)) {
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
