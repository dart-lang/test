// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
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
    checkThat(_testIterable).isRejectedBy(it()..isEmpty(),
        hasWhichThat: it()..deepEquals(['is not empty']));
  });

  test('isNotEmpty', () {
    checkThat(_testIterable).isNotEmpty();
    checkThat(Iterable<int>.empty()).isRejectedBy(it()..isNotEmpty(),
        hasWhichThat: it()..deepEquals(['is not empty']));
  });

  test('contains', () {
    checkThat(_testIterable).contains(0);
    checkThat(_testIterable).isRejectedBy(it()..contains(2),
        hasWhichThat: it()..deepEquals(['does not contain <2>']));
  });
  test('contains', () {
    checkThat(_testIterable).any(it()..equals(1));
    checkThat(_testIterable).isRejectedBy(it()..any(it()..equals(2)),
        hasWhichThat: it()..deepEquals(['Contains no matching element']));
  });
  group('every', () {
    test('succeeds for the happy path', () {
      checkThat(_testIterable).every(it()..isGreaterOrEqual(-1));
    });

    test('includes details of first failing element', () async {
      checkThat(_testIterable).isRejectedBy(it()..every(it()..isLessThan(0)),
          hasWhichThat: it()
            ..deepEquals([
              'has an element at index 0 that:',
              '  Actual: <0>',
              '  Which: is not less than <0>',
            ]));
    });
  });

  group('unorderedEquals', () {
    test('success for happy case', () {
      checkThat(_testIterable).unorderedEquals(_testIterable.toList().reversed);
    });

    test('reports unmatched elements', () {
      checkThat(_testIterable).isRejectedBy(
          it()..unorderedEquals(_testIterable.followedBy([42, 100])),
          hasWhichThat: it()
            ..deepEquals([
              'has no element equal to the expected element at index 2: <42>',
              'or 1 other elements'
            ]));
    });

    test('reports unexpected elements', () {
      checkThat(_testIterable.followedBy([42, 100])).isRejectedBy(
          it()..unorderedEquals(_testIterable),
          hasWhichThat: it()
            ..deepEquals([
              'has an unexpected element at index 2: <42>',
              'and 1 other unexpected elements'
            ]));
    });
  });

  group('unorderedMatches', () {
    test('success for happy case', () {
      checkThat(_testIterable).unorderedMatches(
          _testIterable.toList().reversed.map((i) => it()..equals(i)));
    });

    test('reports unmatched elements', () {
      checkThat(_testIterable).isRejectedBy(
          it()
            ..unorderedMatches(_testIterable
                .followedBy([42, 100]).map((i) => it()..equals(i))),
          hasWhichThat: it()
            ..deepEquals([
              'has no element matching the condition at index 2:',
              '  equals <42>',
              'or 1 other conditions'
            ]));
    });

    test('reports unexpected elements', () {
      checkThat(_testIterable.followedBy([42, 100])).isRejectedBy(
          it()..unorderedMatches(_testIterable.map((i) => it()..equals(i))),
          hasWhichThat: it()
            ..deepEquals([
              'has an unmatched element at index 2: <42>',
              'and 1 other unmatched elements'
            ]));
    });
  });

  group('pairwiseComparesTo', () {
    test('succeeds for the happy path', () {
      checkThat(_testIterable).pairwiseComparesTo(
          [1, 2], (expected) => it()..isLessThan(expected), 'is less than');
    });
    test('fails for mismatched element', () async {
      checkThat(_testIterable).isRejectedBy(
          it()
            ..pairwiseComparesTo([1, 1],
                (expected) => it()..isLessThan(expected), 'is less than'),
          hasWhichThat: it()
            ..deepEquals([
              'does not have an element at index 1 that:',
              '  is less than <1>',
              'Actual element at index 1: <1>',
              'Which: is not less than <1>'
            ]));
    });
    test('fails for too few elements', () {
      checkThat(_testIterable).isRejectedBy(
          it()
            ..pairwiseComparesTo([1, 2, 3],
                (expected) => it()..isLessThan(expected), 'is less than'),
          hasWhichThat: it()
            ..deepEquals([
              'has too few elements, there is no element to match at index 2'
            ]));
    });
    test('fails for too many elements', () {
      checkThat(_testIterable).isRejectedBy(
          it()
            ..pairwiseComparesTo(
                [1], (expected) => it()..isLessThan(expected), 'is less than'),
          hasWhichThat: it()
            ..deepEquals(['has too many elements, expected exactly 1']));
    });
  });
}
