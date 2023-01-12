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
      softCheck<Iterable<int>>(_testIterable, it()..isEmpty()),
    ).isARejection(actual: '(0, 1)', which: ['is not empty']);
  });

  test('isNotEmpty', () {
    checkThat(_testIterable).isNotEmpty();
    checkThat(
      softCheck<Iterable<int>>(Iterable<int>.empty(), it()..isNotEmpty()),
    ).isARejection(actual: '()', which: ['is not empty']);
  });

  test('contains', () {
    checkThat(_testIterable).contains(0);
    checkThat(
      softCheck<Iterable<int>>(_testIterable, it()..contains(2)),
    ).isARejection(actual: '(0, 1)', which: ['does not contain <2>']);
  });
  test('contains', () {
    checkThat(_testIterable).any(it()..equals(1));
    checkThat(
      softCheck<Iterable<int>>(
        _testIterable,
        it()..any(it()..equals(2)),
      ),
    ).isARejection(actual: '(0, 1)', which: ['Contains no matching element']);
  });

  group('every', () {
    test('succeeds for the happy path', () {
      checkThat(_testIterable).every(Condition((e) => e > -1));
    });

    test('includes details of first failing element', () async {
      checkThat(softCheck<Iterable<int>>(
              _testIterable, it()..every(Condition((e) => e < 0))))
          .isARejection(actual: '(0, 1)', which: [
        'has an element at index 0 that:',
        '  Actual: <0>',
        '  Which: is not less than <0>',
      ]);
    });
  });

  group('pairwiseComparesTo', () {
    test('succeeds for the happy path', () {
      checkThat(_testIterable).pairwiseComparesTo(
          [1, 2], (expected) => Condition((c) => c < expected), 'is less than');
    });
    test('fails for mismatched element', () async {
      checkThat(softCheck<Iterable<int>>(
              _testIterable,
              it()
                ..pairwiseComparesTo(
                    [1, 1],
                    (expected) => Condition((c) => c < expected),
                    'is less than')))
          .isARejection(actual: '(0, 1)', which: [
        'does not have an element at index 1 that:',
        '  is less than <1>',
        'Actual element at index 1: <1>',
        'Which: is not less than <1>'
      ]);
    });
    test('fails for too few elements', () {
      checkThat(softCheck<Iterable<int>>(
              _testIterable,
              it()
                ..pairwiseComparesTo(
                    [1, 2, 3],
                    (expected) => Condition((c) => c < expected),
                    'is less than')))
          .isARejection(actual: '(0, 1)', which: [
        'has too few elements, there is no element to match at index 2'
      ]);
    });
    test('fails for too many elements', () {
      checkThat(softCheck<Iterable<int>>(
              _testIterable,
              it()
                ..pairwiseComparesTo(
                    [1],
                    (expected) => Condition((c) => c < expected),
                    'is less than')))
          .isARejection(
              actual: '(0, 1)',
              which: ['has too many elements, expected exactly 1']);
    });
  });
}
