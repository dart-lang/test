// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('DateTime checks', () {
    final noon = DateTime.utc(2026, 1, 1, 12);

    group('isAtSameMomentAs', () {
      test('succeeds for an equal value', () {
        check(noon).isAtSameMomentAs(DateTime.utc(2026, 1, 1, 12));
      });
      test('succeeds across UTC and local values', () {
        check(noon).isAtSameMomentAs(noon.toLocal());
        check(noon.toLocal()).isAtSameMomentAs(noon);
      });
      test('fails for an earlier value', () {
        check(noon).isRejectedBy(
          .it()..isAtSameMomentAs(DateTime.utc(2026, 1, 1, 11)),
          which: ['is <1:00:00.000000> after'],
        );
      });
      test('fails for a later value', () {
        check(noon).isRejectedBy(
          .it()..isAtSameMomentAs(DateTime.utc(2026, 1, 1, 12, 0, 30)),
          which: ['is <0:00:30.000000> before'],
        );
      });
    });

    group('isCloseTo', () {
      const delta = Duration(seconds: 5);
      test('succeeds within the delta', () {
        check(noon).isCloseTo(DateTime.utc(2026, 1, 1, 12, 0, 3), delta);
        check(noon).isCloseTo(DateTime.utc(2026, 1, 1, 11, 59, 57), delta);
      });
      test('succeeds at the delta', () {
        check(noon).isCloseTo(DateTime.utc(2026, 1, 1, 12, 0, 5), delta);
        check(noon).isCloseTo(DateTime.utc(2026, 1, 1, 11, 59, 55), delta);
      });
      test('succeeds across UTC and local values', () {
        check(noon).isCloseTo(noon.toLocal(), delta);
      });
      test('fails beyond the delta', () {
        check(noon).isRejectedBy(
          .it()..isCloseTo(DateTime.utc(2026, 1, 1, 12, 0, 6), delta),
          which: ['differs by <0:00:06.000000>'],
        );
        check(noon).isRejectedBy(
          .it()..isCloseTo(DateTime.utc(2026, 1, 1, 11, 59, 54), delta),
          which: ['differs by <0:00:06.000000>'],
        );
      });
    });

    group('isUtc', () {
      test('succeeds for UTC values', () {
        check(noon).isUtc;
      });
      test('fails for local values', () {
        check(DateTime(2026)).isRejectedBy(.it()..isUtc, which: ['is local']);
      });
    });

    group('isLocal', () {
      test('succeeds for local values', () {
        check(DateTime(2026)).isLocal;
      });
      test('fails for UTC values', () {
        check(noon).isRejectedBy(.it()..isLocal, which: ['is in UTC']);
      });
    });
  });

  group('Duration checks', () {
    group('isCloseTo', () {
      const ten = Duration(seconds: 10);
      const delta = Duration(seconds: 2);
      test('succeeds within the delta', () {
        check(ten).isCloseTo(const Duration(seconds: 11), delta);
        check(ten).isCloseTo(const Duration(seconds: 9), delta);
      });
      test('succeeds at the delta', () {
        check(ten).isCloseTo(const Duration(seconds: 12), delta);
        check(ten).isCloseTo(const Duration(seconds: 8), delta);
      });
      test('fails beyond the delta', () {
        check(ten).isRejectedBy(
          .it()..isCloseTo(const Duration(seconds: 13), delta),
          which: ['differs by <0:00:03.000000>'],
        );
        check(ten).isRejectedBy(
          .it()..isCloseTo(const Duration(seconds: 7), delta),
          which: ['differs by <0:00:03.000000>'],
        );
      });
    });
  });
}
