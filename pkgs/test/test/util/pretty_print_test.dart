// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:test_core/src/util/pretty_print.dart';

void main() {
  group('truncate', () {
    test('returns text that fits unchanged', () {
      expect(truncate('a short message', 15), 'a short message');
    });

    test('keeps the first word and the last words when they fit', () {
      expect(truncate('first a b c d e f g h i j', 20), 'first ... f g h i j');
    });

    test('keeps the end of text that has no spaces', () {
      expect(truncate('abcdefghijklmnop', 10), '...klmnop');
    });

    // A narrow terminal can leave little or no room for the test description
    // once the compact reporter's progress prefix is written.
    group('when there is no room for the text', () {
      const description =
          'AppState Model and Discovery State Tests 3. Clearing search '
          'restores results';

      for (var maxLength in [4, 3, 2, 1, 0, -10]) {
        test('maxLength $maxLength', () {
          var result = truncate(description, maxLength);
          expect(
            result.length,
            lessThanOrEqualTo(maxLength < 0 ? 0 : maxLength),
          );
          expect(result, matches(RegExp(r'^\.*$')));
        });
      }
    });
  });
}
