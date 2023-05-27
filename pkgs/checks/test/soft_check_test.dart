// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import 'test_shared.dart';

void main() {
  group('softCheck', () {
    test('returns the first failure', () {
      check(0).isRejectedBy(
          it()
            ..isGreaterThan(1)
            ..isGreaterThan(2),
          which: ['is not greater than <1>']);
    });
  });
  group('softCheckAsync', () {
    test('returns the first failure', () {
      check(Future.value(0)).isRejectedByAsync(
          it()
            ..completes(it()..isGreaterThan(1))
            ..completes(it()..isGreaterThan(2)),
          actual: ['<0>'],
          which: ['is not greater than <1>']);
    });
  });
}
