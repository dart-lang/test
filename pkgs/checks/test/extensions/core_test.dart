// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('TypeChecks', () {
    test('isA', () {
      checkThat(1).isA<int>();

      checkThat(
        softCheck(1, it()..isA<String>()),
      ).isARejection(actual: ['<1>'], which: ['Is a int']);
    });
  });

  group('HasField', () {
    test('has', () {
      checkThat(1).has((v) => v.isOdd, 'isOdd').isTrue();

      checkThat(
        softCheck<int>(
          2,
          it()..has((v) => throw UnimplementedError(), 'isOdd'),
        ),
      ).isARejection(
        actual: ['<2>'],
        which: ['threw while trying to read property'],
      );
    });

    test('that', () {
      checkThat(true).that(it()..isTrue());
    });

    test('not', () {
      checkThat(false).not(it()..isTrue());

      checkThat(
        softCheck<bool>(
          true,
          it()..not(it()..isTrue()),
        ),
      ).isARejection(
        actual: ['<true>'],
        which: ['is a value that: ', '    is true'],
      );
    });
  });

  group('BoolChecks', () {
    test('isTrue', () {
      checkThat(true).isTrue();

      checkThat(
        softCheck<bool>(
          false,
          it()..isTrue(),
        ),
      ).isARejection(actual: ['<false>']);
    });

    test('isFalse', () {
      checkThat(false).isFalse();

      checkThat(softCheck<bool>(
        true,
        it()..isFalse(),
      )).isARejection(actual: ['<true>']);
    });
  });

  group('EqualityChecks', () {
    test('equals', () {
      checkThat(1).equals(1);

      checkThat(
        softCheck(1, it()..equals(2)),
      ).isARejection(actual: ['<1>'], which: ['are not equal']);
    });

    test('identical', () {
      checkThat(1).identicalTo(1);

      checkThat(softCheck(1, it()..identicalTo(2)))
          .isARejection(actual: ['<1>'], which: ['is not identical']);
    });
  });

  group('NullabilityChecks', () {
    test('isNotNull', () {
      checkThat(1).isNotNull();

      checkThat(softCheck(null, it()..isNotNull()))
          .isARejection(actual: ['<null>']);
    });

    test('isNull', () {
      checkThat(null).isNull();

      checkThat(softCheck(1, it()..isNull())).isARejection(actual: ['<1>']);
    });
  });
}
