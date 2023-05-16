// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/precache.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_cache.dart';

class TizenPrecacheCommand extends PrecacheCommand {
  TizenPrecacheCommand({
    super.verboseHelp,
    required super.cache,
    required super.platform,
    required super.logger,
    required super.featureFlags,
  })  : _cache = cache,
        _platform = platform {
    argParser.addFlag(
      'tizen',
      help: 'Precache artifacts for Tizen development.',
    );
  }

  final Cache _cache;
  final Platform _platform;

  bool get _includeOtherPlatforms {
    final bool includeAndroid = boolArg('android');
    bool explicitlySelected(String name) =>
        argResults!.wasParsed(name) && boolArg(name);
    return includeAndroid ||
        DevelopmentArtifact.values
            .map((DevelopmentArtifact artifact) => artifact.name)
            .any(explicitlySelected);
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    final bool includeAllPlatforms = boolArg('all-platforms');
    final bool includeTizen = boolArg('tizen');
    final bool includeDefaults = !includeTizen && !_includeOtherPlatforms;

    // Re-lock the cache.
    if (_platform.environment['FLUTTER_ALREADY_LOCKED'] != 'true') {
      await _cache.lock();
    }

    if (includeAllPlatforms || includeDefaults || includeTizen) {
      if (boolArg('force')) {
        _cache.setStampFor(kTizenEngineStampName, '');
        _cache.setStampFor(kTizenEmbedderStampName, '');
      }
      await _cache.updateAll(<DevelopmentArtifact>{
        TizenDevelopmentArtifact.tizen,
      });
    }

    // Release lock of the cache.
    _cache.releaseLock();

    if (includeAllPlatforms || includeDefaults || _includeOtherPlatforms) {
      // If the --force option is set, super.runCommand() will delete all
      // Tizen stamp files. They must be restored.
      final String? engineStamp = _cache.getStampFor(kTizenEngineStampName);
      final String? embedderStamp = _cache.getStampFor(kTizenEmbedderStampName);
      final FlutterCommandResult result = await super.runCommand();
      if (engineStamp != null) {
        _cache.setStampFor(kTizenEngineStampName, engineStamp);
      }
      if (embedderStamp != null) {
        _cache.setStampFor(kTizenEmbedderStampName, embedderStamp);
      }
      return result;
    }

    return FlutterCommandResult.success();
  }
}
