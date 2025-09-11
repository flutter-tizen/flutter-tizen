// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:flutter_tizen/commands/precache.dart';
import 'package:flutter_tizen/tizen_cache.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:test/fake.dart';

import '../src/context.dart';
import '../src/fakes.dart';
import '../src/test_flutter_command_runner.dart';

void main() {
  late _FakeCache cache;
  late TizenPrecacheCommand command;

  setUp(() {
    cache = _FakeCache();
    command = TizenPrecacheCommand(
      cache: cache,
      platform: FakePlatform(),
      logger: BufferLogger.test(),
      featureFlags: TestFeatureFlags(),
    );
  });

  testUsingContext('Get all artifacts for this platform', () async {
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>['precache']);

    expect(
      cache.artifacts,
      unorderedEquals(<DevelopmentArtifact>{
        DevelopmentArtifact.universal,
        DevelopmentArtifact.androidGenSnapshot,
        DevelopmentArtifact.androidMaven,
        DevelopmentArtifact.androidInternalBuild,
        DevelopmentArtifact.iOS,
        TizenDevelopmentArtifact.tizen,
      }),
    );
  });

  testUsingContext('Get Tizen artifacts', () async {
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>['precache', '--tizen']);

    expect(
      cache.artifacts,
      unorderedEquals(<DevelopmentArtifact>{
        TizenDevelopmentArtifact.tizen,
      }),
    );
  });

  testUsingContext('Clear Tizen stamp if --force is provided', () async {
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>['precache', '--force']);

    expect(cache.engineStamp, isEmpty);
    expect(cache.embedderStamp, isEmpty);
  });
}

class _FakeCache extends Fake implements Cache {
  var artifacts = <DevelopmentArtifact>{};
  String? engineStamp;
  String? embedderStamp;

  @override
  var includeAllPlatforms = false;

  @override
  Set<String>? platformOverrideArtifacts = <String>{};

  @override
  Future<void> lock() async {}

  @override
  void releaseLock() {}

  @override
  String? getStampFor(String artifactName) {
    if (artifactName == kTizenEngineStampName) {
      return engineStamp;
    } else if (artifactName == kTizenEmbedderStampName) {
      return embedderStamp;
    }
    return null;
  }

  @override
  void setStampFor(String artifactName, String version) {
    if (artifactName == kTizenEngineStampName) {
      engineStamp = version;
    } else if (artifactName == kTizenEmbedderStampName) {
      embedderStamp = version;
    }
  }

  @override
  void clearStampFiles() {}

  @override
  Future<bool> isUpToDate() async => false;

  @override
  Future<void> updateAll(
    Set<DevelopmentArtifact> requiredArtifacts, {
    bool offline = false,
  }) async {
    artifacts.addAll(requiredArtifacts);
  }
}
