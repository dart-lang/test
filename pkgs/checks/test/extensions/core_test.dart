// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('TypeChecks', () {
    test('isA', () {
      1.must.beA<int>();

      1.must.beRejectedBy(would()..beA<String>(), which: ['Is a int']);
    });
  });
  group('HasField', () {
    test('has', () {
      1.must.have((v) => v.isOdd, 'isOdd').beTrue();

      2.must.beRejectedBy(
          would()..have((v) => throw UnimplementedError(), 'isOdd'),
          which: ['threw while trying to read property']);
    });

    test('which', () {
      true.must.which(would()..beTrue());
    });

    test('not', () {
      false.must.not(would()..beTrue());

      true.must.beRejectedBy(would()..not(would()..beTrue()), which: [
        'is a value that: ',
        '    is true',
      ]);
    });

    group('anyOf', () {
      test('succeeds for happy case', () {
        (-10).must.anyOf([would()..beGreaterThan(1), would()..beLessThat(-1)]);
      });

      test('rejects values that do not satisfy any condition', () {
        0.must.beRejectedBy(
            would()
              ..anyOf([would()..beGreaterThan(1), would()..beLessThat(-1)]),
            which: ['did not match any condition']);
      });
    });
  });

  group('BoolChecks', () {
    test('isTrue', () {
      true.must.beTrue();

      false.must.beRejectedBy(would()..beTrue());
    });

    test('isFalse', () {
      false.must.beFalse();

      true.must.beRejectedBy(would()..beFalse());
    });
  });

  group('EqualityChecks', () {
    test('equals', () {
      1.must.equal(1);

      1.must.beRejectedBy(would()..equal(2), which: ['are not equal']);
    });
    test('identical', () {
      1.must.beIdenticalTo(1);

      1
          .must
          .beRejectedBy(would()..beIdenticalTo(2), which: ['is not identical']);
    });
  });
  group('NullabilityChecks', () {
    test('isNotNull', () {
      1.must.beNonNull();

      null.must.beRejectedBy(would()..beNonNull());
    });
    test('isNull', () {
      null.must.beNull();

      1.must.beRejectedBy(would()..beNull());
    });
  });
}
