// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tizen/tizen_flutter_version.dart';

import '../src/common.dart';

void main() {
  group('TizenGitTagVersion.parse', () {
    testWithoutContext('parses current-scheme release tags', () {
      final TizenGitTagVersion? tag = TizenGitTagVersion.parse('3.44.4-tizen.1.0.0');
      expect(tag, isNotNull);
      expect(tag!.flutterVersion, '3.44.4');
      expect(tag.toolVersion, '1.0.0');
    });

    testWithoutContext('parses legacy bare release tags', () {
      final TizenGitTagVersion? tag = TizenGitTagVersion.parse('3.44.4');
      expect(tag, isNotNull);
      expect(tag!.tag, '3.44.4');
      expect(tag.flutterVersion, '3.44.4');
      expect(tag.toolVersion, isNull);
    });

    testWithoutContext('ignores non-release tags', () {
      expect(TizenGitTagVersion.parse('v3.44.4-tizen.1.0.0'), isNull);
      expect(TizenGitTagVersion.parse('3.44'), isNull);
      expect(TizenGitTagVersion.parse('nightly'), isNull);
    });
  });

  group('TizenGitTagVersion.parseTags', () {
    testWithoutContext('keeps newest-first order, keeps bare tags, drops others', () {
      final List<TizenGitTagVersion> tags = TizenGitTagVersion.parseTags(
        '3.44.8-tizen.1.0.0\n3.44.4-tizen.1.0.0\n3.44.4\n3.44.1-tizen.1.1.0\nsome-branch-tag\n',
      );
      expect(tags.map((TizenGitTagVersion tag) => tag.tag), <String>[
        '3.44.8-tizen.1.0.0',
        '3.44.4-tizen.1.0.0',
        '3.44.4',
        '3.44.1-tizen.1.1.0',
      ]);
    });
  });
}
