// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

Iterable<int> get _testIterable => Iterable.generate(2, (i) => i);

void main() {
  test('length', () {
    checkThat(_testIterable).length.equals(2);
  });
  test('first', () {
    checkThat(_testIterable).first.equals(0);
  });
  test('last', () {
    checkThat(_testIterable).last.equals(1);
  });
  test('single', () {
    checkThat([42]).single.equals(42);
  });

  test('isEmpty', () {
    checkThat([]).isEmpty();
    checkThat(
      softCheck<Iterable<int>>(_testIterable, (p0) => p0.isEmpty()),
    ).isARejection(actual: '(0, 1)', which: ['is not empty']);
  });

  test('isNotEmpty', () {
    checkThat(_testIterable).isNotEmpty();
    checkThat(
      softCheck<Iterable<int>>(Iterable<int>.empty(), (p0) => p0.isNotEmpty()),
    ).isARejection(actual: '()', which: ['is not empty']);
  });

  test('contains', () {
    checkThat(_testIterable).contains(0);
    checkThat(
      softCheck<Iterable<int>>(_testIterable, (p0) => p0.contains(2)),
    ).isARejection(actual: '(0, 1)', which: ['does not contain <2>']);
  });
  test('contains', () {
    checkThat(_testIterable).any((p0) => p0.equals(1));
    checkThat(
      softCheck<Iterable<int>>(
        _testIterable,
        (p0) => p0.any((p1) => p1.equals(2)),
      ),
    ).isARejection(actual: '(0, 1)', which: ['Contains no matching element']);
  });
}
