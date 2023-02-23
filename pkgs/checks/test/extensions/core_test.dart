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

      check(1).isRejectedBy((it) => it.isA<String>(), which: ['Is a int']);
    });
  });
  group('HasField', () {
    test('has', () {
      check(1).has((v) => v.isOdd, 'isOdd').isTrue();

      check(null).isRejectedBy(
          (it) => it.has((v) {
                Error.throwWithStackTrace(
                    UnimplementedError(), StackTrace.fromString('fake trace'));
              }, 'foo').isNotNull(),
          which: [
            'threw while trying to read foo: <UnimplementedError>',
            'fake trace'
          ]);
    });

    test('which', () {
      check(true).which((it) => it.isTrue());
    });

    test('not', () {
      check(false).not((it) => it.isTrue());
      check(true).isRejectedBy((it) => it.not((it) => it.isTrue()), which: [
        'is a value that: ',
        '    is true',
      ]);
    });

    group('anyOf', () {
      test('succeeds for happy case', () {
        check(-10)
            .anyOf([(it) => it.isGreaterThan(1), (it) => it.isLessThan(-1)]);
      });
      test('rejects values that do not satisfy any condition', () {
        check(0).isRejectedBy(
            (it) => it.anyOf(
                [(it) => it.isGreaterThan(1), (it) => it.isLessThan(-1)]),
            which: ['did not match any condition']);
      });
    });
  });

  group('BoolChecks', () {
    test('isTrue', () {
      check(true).isTrue();

      check(false).isRejectedBy((it) => it.isTrue());
    });

    test('isFalse', () {
      check(false).isFalse();

      check(true).isRejectedBy((it) => it.isFalse());
    });
  });

  group('EqualityChecks', () {
    test('equals', () {
      check(1).equals(1);

      check(1).isRejectedBy((it) => it.equals(2), which: ['are not equal']);
    });
    test('identical', () {
      check(1).identicalTo(1);

      check(1)
          .isRejectedBy((it) => it.identicalTo(2), which: ['is not identical']);
    });
  });
  group('NullabilityChecks', () {
    test('isNotNull', () {
      check(1).isNotNull();

      check(null).isRejectedBy((it) => it.isNotNull());
    });
    test('isNull', () {
      check(null).isNull();

      check(1).isRejectedBy((it) => it.isNull());
    });
  });
}
