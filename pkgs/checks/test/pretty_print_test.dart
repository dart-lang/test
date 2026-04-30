// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('literal', () {
    group('truncates large collections', () {
      const maxUntruncatedCollection = 25;
      final largeList = List<int>.generate(
        maxUntruncatedCollection + 1,
        (i) => i,
      );
      test('in lists', () {
        check(literal(largeList)).last.equals('...]');
      });
      test('in sets', () {
        check(literal(largeList.toSet())).last.equals('...}');
      });
      test('in iterables', () {
        check(literal(largeList.followedBy([]))).last.equals('...)');
      });
      test('without processing truncated elements', () {
        final poisonedList = [...largeList, _PoisonToString()];
        check(() {
          literal(poisonedList);
        }).returnsNormally();
      });
      test('in maps', () {
        final map = Map<int, int>.fromIterables(largeList, largeList);
        check(literal(map)).last.equals('...}');
      });
    });
  });
}

class _PoisonToString {
  @override
  String toString() =>
      throw StateError('Truncated entry should not be processed');
}
