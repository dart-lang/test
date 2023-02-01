// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

Iterable<int> get _testIterable => Iterable.generate(2, (i) => i);

void main() {
  test('length', () {
    _testIterable.must.haveLength.equal(2);
  });
  test('first', () {
    _testIterable.must.haveFirst.equal(0);
  });
  test('last', () {
    _testIterable.must.haveLast.equal(1);
  });
  test('single', () {
    [42].must.haveSingleElement.equal(42);
  });

  test('isEmpty', () {
    [].must.beEmpty();
    _testIterable.must
        .beRejectedBy(would()..beEmpty(), which: ['is not empty']);
  });

  test('isNotEmpty', () {
    _testIterable.must.beNotEmpty();
    Iterable<int>.empty()
        .must
        .beRejectedBy(would()..beNotEmpty(), which: ['is not empty']);
  });

  test('contains', () {
    _testIterable.must.contain(0);
    _testIterable.must
        .beRejectedBy(would()..contain(2), which: ['does not contain <2>']);
  });
  test('any', () {
    _testIterable.must.containElementWhich(would()..equal(1));
    _testIterable.must.beRejectedBy(
        would()..containElementWhich(would()..equal(2)),
        which: ['Contains no matching element']);
  });

  group('containsInOrder', () {
    test('succeeds for happy case', () {
      [0, 1, 0, 2, 0, 3].must.containInOrder([1, 2, 3]);
    });
    test('can use Condition<dynamic>', () {
      [0, 1].must.containInOrder([would()..beA<int>().beGreaterThan(0)]);
    });
    test('can use Condition<T>', () {
      [0, 1].must.containInOrder([would<int>()..beGreaterThan(0)]);
    });
    test('fails for not found elements by equality', () async {
      [0].must.beRejectedBy(would()..containInOrder([1]), which: [
        'did not have an element matching the expectation at index 0 <1>'
      ]);
    });
    test('fails for not found elements by condition', () async {
      [0].must.beRejectedBy(
          would()..containInOrder([would()..beA<int>().beGreaterThan(0)]),
          which: [
            'did not have an element matching the expectation at index 0 '
                '<A value that:',
            '  is a int',
            '  is greater than <0>>'
          ]);
    });
    test('can be described', () {
      (would<Iterable>()..containInOrder([1, 2, 3]))
          .must
          .haveDescription
          .deeplyEqual(['  contains, in order: [1, 2, 3]']);
      (would<Iterable>()..containInOrder([1, would()..equal(2)]))
          .must
          .haveDescription
          .deeplyEqual([
        '  contains, in order: [1,',
        '  A value that:',
        '    equals <2>]'
      ]);
    });
  });
  group('every', () {
    test('succeeds for the happy path', () {
      _testIterable.must
          .containOnlyElementsWhich(would()..beGreaterOrEqual(-1));
    });

    test('includes details of first failing element', () async {
      _testIterable.must.beRejectedBy(
          would()..containOnlyElementsWhich(would()..beLessThat(0)),
          which: [
            'has an element at index 0 that:',
            '  Actual: <0>',
            '  Which: is not less than <0>',
          ]);
    });
  });

  group('unorderedEquals', () {
    test('success for happy case', () {
      _testIterable.must.unorderedEqual(_testIterable.toList().reversed);
    });

    test('reports unmatched elements', () {
      _testIterable.must.beRejectedBy(
          would()..unorderedEqual(_testIterable.followedBy([42, 100])),
          which: [
            'has no element equal to the expected element at index 2: <42>',
            'or 1 other elements'
          ]);
    });

    test('reports unexpected elements', () {
      (_testIterable.followedBy([42, 100]))
          .must
          .beRejectedBy(would()..unorderedEqual(_testIterable), which: [
        'has an unexpected element at index 2: <42>',
        'and 1 other unexpected elements'
      ]);
    });
  });

  group('unorderedMatches', () {
    test('success for happy case', () {
      _testIterable.must.unorderedMatches(
          _testIterable.toList().reversed.map((i) => would()..equal(i)));
    });

    test('reports unmatched elements', () {
      _testIterable.must.beRejectedBy(
          would()
            ..unorderedMatches(_testIterable
                .followedBy([42, 100]).map((i) => would()..equal(i))),
          which: [
            'has no element matching the condition at index 2:',
            '  equals <42>',
            'or 1 other conditions'
          ]);
    });

    test('reports unexpected elements', () {
      (_testIterable.followedBy([42, 100])).must.beRejectedBy(
          would()
            ..unorderedMatches(_testIterable.map((i) => would()..equal(i))),
          which: [
            'has an unmatched element at index 2: <42>',
            'and 1 other unmatched elements'
          ]);
    });
  });

  group('pairwiseComparesTo', () {
    test('succeeds for the happy path', () {
      _testIterable.must.pairwiseCompareTo(
          [1, 2], (expected) => would()..beLessThat(expected), 'is less than');
    });
    test('fails for mismatched element', () async {
      _testIterable.must.beRejectedBy(
          would()
            ..pairwiseCompareTo([1, 1],
                (expected) => would()..beLessThat(expected), 'is less than'),
          which: [
            'does not have an element at index 1 that:',
            '  is less than <1>',
            'Actual element at index 1: <1>',
            'Which: is not less than <1>'
          ]);
    });
    test('fails for too few elements', () {
      _testIterable.must.beRejectedBy(
          would()
            ..pairwiseCompareTo([1, 2, 3],
                (expected) => would()..beLessThat(expected), 'is less than'),
          which: [
            'has too few elements, there is no element to match at index 2'
          ]);
    });
    test('fails for too many elements', () {
      _testIterable.must.beRejectedBy(
          would()
            ..pairwiseCompareTo([1],
                (expected) => would()..beLessThat(expected), 'is less than'),
          which: ['has too many elements, expected exactly 1']);
    });
  });
}
