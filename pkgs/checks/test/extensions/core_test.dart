// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('TypeChecks', () {
    test('isA', () {
      checkThat(1).isA<int>();

      checkThat(1).isRejectedBy(it()..isA<String>(),
          hasWhichThat: it()..deepEquals(['Is a int']));
    });
  });
  group('HasField', () {
    test('has', () {
      checkThat(1).has((v) => v.isOdd, 'isOdd').isTrue();

      checkThat(2).isRejectedBy(
        it()..has((v) => throw UnimplementedError(), 'isOdd'),
        hasWhichThat: it()..deepEquals(['threw while trying to read property']),
      );
    });

    test('that', () {
      checkThat(true).that(it()..isTrue());
    });

    test('not', () {
      checkThat(false).not(it()..isTrue());

      checkThat(true).isRejectedBy(
        it()..not(it()..isTrue()),
        hasWhichThat: it()..deepEquals(['is a value that: ', '    is true']),
      );
    });

    group('anyOf', () {
      test('succeeds for happy case', () {
        checkThat(-10).anyOf([it()..isGreaterThan(1), it()..isLessThan(-1)]);
      });

      test('rejects values that do not satisfy any condition', () {
        checkThat(0).isRejectedBy(
            it()..anyOf([it()..isGreaterThan(1), it()..isLessThan(-1)]),
            hasWhichThat: it()..deepEquals(['did not match any condition']));
      });
    });
  });

  group('BoolChecks', () {
    test('isTrue', () {
      checkThat(true).isTrue();

      checkThat(false).isRejectedBy(it()..isTrue());
    });

    test('isFalse', () {
      checkThat(false).isFalse();

      checkThat(true).isRejectedBy(it()..isFalse());
    });
  });

  group('EqualityChecks', () {
    test('equals', () {
      checkThat(1).equals(1);

      checkThat(1).isRejectedBy(it()..equals(2),
          hasWhichThat: it()..deepEquals(['are not equal']));
    });
    test('identical', () {
      checkThat(1).identicalTo(1);

      checkThat(1).isRejectedBy(it()..identicalTo(2),
          hasWhichThat: it()..deepEquals(['is not identical']));
    });
  });
  group('NullabilityChecks', () {
    test('isNotNull', () {
      checkThat(1).isNotNull();

      checkThat(null).isRejectedBy(it()..isNotNull());
    });
    test('isNull', () {
      checkThat(null).isNull();

      checkThat(1).isRejectedBy(it()..isNull());
    });
  });
}
