// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/precache.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_cache.dart';

const String kTizenStampName = 'tizen-sdk';

class TizenPrecacheCommand extends PrecacheCommand {
  TizenPrecacheCommand({
    super.verboseHelp,
    required super.cache,
    required super.platform,
    required super.logger,
    required super.featureFlags,
  })  : _cache = cache!,
        _platform = platform {
    argParser.addFlag(
      'tizen',
      help: 'Precache artifacts for Tizen development.',
    );
  }

  final Cache _cache;
  final Platform _platform;

  bool get _includeOtherPlatforms {
    final bool includeAndroid = boolArg('android') ?? false;
    bool explicitlySelected(String name) =>
        argResults!.wasParsed(name) && boolArg(name)!;
    return includeAndroid ||
        DevelopmentArtifact.values
            .map((DevelopmentArtifact artifact) => artifact.name)
            .any(explicitlySelected);
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    final bool includeAllPlatforms = boolArg('all-platforms') ?? false;
    final bool includeTizen = boolArg('tizen') ?? false;
    final bool includeDefaults = !includeTizen && !_includeOtherPlatforms;

    // Re-lock the cache.
    if (_platform.environment['FLUTTER_ALREADY_LOCKED'] != 'true') {
      await _cache.lock();
    }

    if (includeAllPlatforms || includeDefaults || includeTizen) {
      if (boolArg('force') ?? false) {
        _cache.setStampFor(kTizenStampName, '');
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
      final String? tizenStamp = _cache.getStampFor(kTizenStampName);
      final FlutterCommandResult result = await super.runCommand();
      if (tizenStamp != null) {
        _cache.setStampFor(kTizenStampName, tizenStamp);
      }
      return result;
    }

    return FlutterCommandResult.success();
  }
}
