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

      check(null).isRejectedBy(
          it()
            ..has((v) {
              Error.throwWithStackTrace(
                  UnimplementedError(), StackTrace.fromString('fake trace'));
            }, 'foo')
                .isNotNull(),
          which: [
            'threw while trying to read foo: <UnimplementedError>',
            'fake trace'
          ]);
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

  group('ComparableChecks on Duration', () {
    group('isGreaterThan', () {
      test('succeeds for greater', () {
        check(Duration(seconds: 10)).isGreaterThan(Duration(seconds: 1));
      });
      test('fails for equal', () {
        check(Duration(seconds: 10)).isRejectedBy(
            it()..isGreaterThan(Duration(seconds: 10)),
            which: ['is not greater than <0:00:10.000000>']);
      });
      test('fails for less', () {
        check(Duration(seconds: 10)).isRejectedBy(
            it()..isGreaterThan(Duration(seconds: 50)),
            which: ['is not greater than <0:00:50.000000>']);
      });
    });
    group('isGreaterOrEqual', () {
      test('succeeds for greater', () {
        check(Duration(seconds: 10)).isGreaterOrEqual(Duration(seconds: 1));
      });
      test('succeeds for equal', () {
        check(Duration(seconds: 10)).isGreaterOrEqual(Duration(seconds: 10));
      });
      test('fails for less', () {
        check(Duration(seconds: 10)).isRejectedBy(
            it()..isGreaterOrEqual(Duration(seconds: 50)),
            which: ['is not greater than or equal to <0:00:50.000000>']);
      });
    });
    group('isLessThan', () {
      test('succeeds for less', () {
        check(Duration(seconds: 1)).isLessThan(Duration(seconds: 10));
      });
      test('fails for equal', () {
        check(Duration(seconds: 10)).isRejectedBy(
            it()..isLessThan(Duration(seconds: 10)),
            which: ['is not less than <0:00:10.000000>']);
      });
      test('fails for greater', () {
        check(Duration(seconds: 50)).isRejectedBy(
            it()..isLessThan(Duration(seconds: 10)),
            which: ['is not less than <0:00:10.000000>']);
      });
    });
    group('isLessOrEqual', () {
      test('succeeds for less', () {
        check(Duration(seconds: 10)).isLessOrEqual(Duration(seconds: 50));
      });
      test('succeeds for equal', () {
        check(Duration(seconds: 10)).isLessOrEqual(Duration(seconds: 10));
      });
      test('fails for greater', () {
        check(Duration(seconds: 10)).isRejectedBy(
            it()..isLessOrEqual(Duration(seconds: 1)),
            which: ['is not less than or equal to <0:00:01.000000>']);
      });
    });
  });
}
