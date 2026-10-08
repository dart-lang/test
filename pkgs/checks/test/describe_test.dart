// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import 'test_shared.dart';

void main() {
  group('describe', () {
    test('succeeds for empty conditions', () {
      check(Condition.it<void>()).hasSyncDescription().isEmpty;
    });
    test('includes condition clauses', () {
      check(
        Condition.it<int>()..equals(1),
      ).hasSyncDescription().deepEquals(['  equals <1>']);
    });
    test('includes nested clauses', () {
      check(
        Condition.it<String>()
          ..length.which(
            .it()
              ..isGreaterThan(0)
              ..isLessThan(2),
          ),
      ).hasSyncDescription().deepEquals([
        '  has length that:',
        '    is greater than <0>',
        '    is less than <2>',
      ]);
    });
    test('collapses nested subjects with a single expectation', () {
      check(
        Condition.it<String>()..length.equals(1),
      ).hasSyncDescription().deepEquals(['  has length: <1>']);
    });
    test('collapses through satisfied preconditions', () {
      check(
        Condition.it<Object?>()
          ..has((o) => o, 'self').isA<String>().length.equals(1),
      ).hasSyncDescription().deepEquals(['  has self that has length: <1>']);
    });
    test('collapses passing clauses alongside uncollapsible ones', () {
      check(
        Condition.it<String>()
          ..length.equals(1)
          ..startsWith('a'),
      ).hasSyncDescription().deepEquals([
        '  has length: <1>',
        "  starts with 'a'",
      ]);
    });
  });
}
