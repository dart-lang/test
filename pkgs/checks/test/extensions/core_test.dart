// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('TypeChecks', () {
    test('isA', () {
      check(1).isA<int>();

      check(1).isRejectedBy(it()..isA<String>(), which: ['Is a int']);
    });
  });
  group('HasField', () {
    test('has', () {
      check(1).has((v) => v.isOdd, 'isOdd').isTrue();

      check(2).isRejectedBy(
          it()..has((v) => throw UnimplementedError(), 'isOdd'),
          which: ['threw while trying to read property']);
    });

    test('which', () {
      check(true).which(it()..isTrue());
    });

    test('not', () {
      check(false).not(it()..isTrue());

      check(true).isRejectedBy(it()..not(it()..isTrue()), which: [
        'is a value that: ',
        '    is true',
      ]);
    });

    group('anyOf', () {
      test('succeeds for happy case', () {
        check(-10).anyOf([it()..isGreaterThan(1), it()..isLessThan(-1)]);
      });

      test('rejects values that do not satisfy any condition', () {
        check(0).isRejectedBy(
            it()..anyOf([it()..isGreaterThan(1), it()..isLessThan(-1)]),
            which: ['did not match any condition']);
      });
    });
  });

  group('BoolChecks', () {
    test('isTrue', () {
      check(true).isTrue();

      check(false).isRejectedBy(it()..isTrue());
    });

    test('isFalse', () {
      check(false).isFalse();

      check(true).isRejectedBy(it()..isFalse());
    });
  });

  group('EqualityChecks', () {
    test('equals', () {
      check(1).equals(1);

      check(1).isRejectedBy(it()..equals(2), which: ['are not equal']);
    });
    test('identical', () {
      check(1).identicalTo(1);

      check(1).isRejectedBy(it()..identicalTo(2), which: ['is not identical']);
    });
  });
  group('NullabilityChecks', () {
    test('isNotNull', () {
      check(1).isNotNull();

      check(null).isRejectedBy(it()..isNotNull());
    });
    test('isNull', () {
      check(null).isNull();

      check(1).isRejectedBy(it()..isNull());
    });
  });
}
