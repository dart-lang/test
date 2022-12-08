// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

void main() {
  group('spawnHybridCode', () {
    test('uses the current package language version by default', () async {
      final channel = spawnHybridCode(_hybridMain);
      expect(await channel.stream.single, equals(true));
    });

    test('can set the language version with a marker', () async {
      final channel = spawnHybridCode('// @dart=2.12\n$_hybridMain');
      expect(await channel.stream.single, equals(false));
    });
  });
}

const _hybridMain = '''
final isOptedOut = <int?>[] is List<int>;

void hybridMain(dynamic channel) async {
  channel.sink.add(isOptedOut);
  channel.sink.close();
}
''';
