// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

void main() {
  group('spawnHybridCode()', () {
    test('can opt out of null safety', () async {
      expect(spawnHybridCode('''
        // @dart=2.9
        import "package:stream_channel/stream_channel.dart";

        // Would cause an error in null safety mode.
        int x;

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').stream.toList(), completion(equals([1, 2, 3])));
    });

    test('opts in to null safety by default', () async {
      expect(spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        // Use some null safety syntax
        int? x;

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').stream.toList(), completion(equals([1, 2, 3])));
    });
  });
}
