// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/precache.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:meta/meta.dart';

import '../tizen_cache.dart';

class TizenPrecacheCommand extends PrecacheCommand {
  TizenPrecacheCommand({
    bool verboseHelp = false,
    @required Cache cache,
    @required Platform platform,
    @required Logger logger,
    @required FeatureFlags featureFlags,
  })  : _cache = cache,
        _platform = platform,
        super(
          verboseHelp: verboseHelp,
          cache: cache,
          platform: platform,
          logger: logger,
          featureFlags: featureFlags,
        ) {
    argParser.addFlag(
      'tizen',
      negatable: true,
      defaultsTo: false,
      help: 'Precache artifacts for Tizen development.',
    );
  }

  final Cache _cache;
  final Platform _platform;

  bool get _includeOtherPlatforms =>
      boolArg('android') ||
      DevelopmentArtifact.values.any((DevelopmentArtifact artifact) =>
          boolArg(artifact.name) && argResults.wasParsed(artifact.name));

  @override
  Future<FlutterCommandResult> runCommand() async {
    final bool includeAllPlatforms = boolArg('all-platforms');
    final bool includeTizen = boolArg('tizen');
    final bool includeDefaults = !includeTizen && !_includeOtherPlatforms;

    const String tizenStampName = 'tizen-sdk';

    // Re-lock the cache.
    if (_platform.environment['FLUTTER_ALREADY_LOCKED'] != 'true') {
      await _cache.lock();
    }

    if (includeAllPlatforms || includeDefaults || includeTizen) {
      if (boolArg('force')) {
        _cache.setStampFor(tizenStampName, '');
      }
      await _cache.updateAll(<DevelopmentArtifact>{
        TizenDevelopmentArtifact.tizen,
      });
    }

    // Release lock of the cache.
    _cache.releaseLock();

    if (includeAllPlatforms || includeDefaults || _includeOtherPlatforms) {
      // If the '--force' option is used, the super.runCommand() will delete
      // the tizen's stamp file. It should be restored.
      final String tizenStamp = _cache.getStampFor(tizenStampName);
      final FlutterCommandResult result = await super.runCommand();
      if (tizenStamp != null) {
        _cache.setStampFor(tizenStampName, tizenStamp);
      }
      return result;
    }

    return FlutterCommandResult.success();
  }
}
