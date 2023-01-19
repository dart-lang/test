// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
import 'package:test/test.dart';

void main() {
  group('spawnHybridUri():', () {
    test('loads uris relative to the test file', () async {
      expect(
          spawnHybridUri(Uri.parse('../util/emits_numbers.dart'))
              .stream
              .toList(),
          completion(equals([1, 2, 3])));
    });
  });
}
