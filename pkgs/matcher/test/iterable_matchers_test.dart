// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('isEmpty', () {
    shouldPass([], isEmpty);
    shouldFail([1], isEmpty, 'Expected: empty Actual: [1]');
  });

  test('isNotEmpty', () {
    shouldFail([], isNotEmpty, 'Expected: non-empty Actual: []');
    shouldPass([1], isNotEmpty);
  });

  test('contains', () {
    var d = [1, 2];
    shouldPass(d, contains(1));
    shouldFail(
        d,
        contains(0),
        'Expected: contains <0> '
        'Actual: [1, 2] '
        'Which: does not contain <0>');

    shouldFail(
        'String',
        contains(42),
        "Expected: contains <42> Actual: 'String' "
            'Which: does not contain <42>');
  });

  test('equals with matcher element', () {
    var d = ['foo', 'bar'];
    shouldPass(d, equals(['foo', startsWith('ba')]));
    shouldFail(
        d,
        equals(['foo', endsWith('ba')]),
        "Expected: ['foo', <a string ending with 'ba'>] "
        "Actual: ['foo', 'bar'] "
        "Which: at location [1] is 'bar' which "
        "does not match a string ending with 'ba'");
  });

  test('isIn', () {
    // Iterable
    shouldPass(1, isIn([1, 2]));
    shouldFail(0, isIn([1, 2]), 'Expected: is in [1, 2] Actual: <0>');

    // Map
    shouldPass(1, isIn({1: null}));
    shouldFail(0, isIn({1: null}), 'Expected: is in {1: null} Actual: <0>');

    // String
    shouldPass('42', isIn('1421'));
    shouldFail('42', isIn('41'), "Expected: is in '41' Actual: '42'");
    shouldFail(
        0, isIn('a string'), endsWith('not an <Instance of \'Pattern\'>'));

    // Invalid arg
    expect(() => isIn(42), throwsArgumentError);
  });

  test('everyElement', () {
    var d = [1, 2];
    var e = [1, 1, 1];
    shouldFail(
        d,
        everyElement(1),
        'Expected: every element(<1>) '
        'Actual: [1, 2] '
        "Which: has value <2> which doesn't match <1> at index 1");
    shouldPass(e, everyElement(1));
    shouldFail('not iterable', everyElement(1),
        endsWith('not an <Instance of \'Iterable\'>'));
  });

  test('nested everyElement', () {
    var d = [
      ['foo', 'bar'],
      ['foo'],
      <Object?>[]
    ];
    var e = [
      ['foo', 'bar'],
      ['foo'],
      3,
      <Object?>[]
    ];
    shouldPass(d, everyElement(anyOf(isEmpty, contains('foo'))));
    shouldFail(
        d,
        everyElement(everyElement(equals('foo'))),
        "Expected: every element(every element('foo')) "
        "Actual: [['foo', 'bar'], ['foo'], []] "
        "Which: has value ['foo', 'bar'] which has value 'bar' "
        'which is different. Expected: foo Actual: bar ^ '
        'Differ at offset 0 at index 1 at index 0');
    shouldFail(
        d,
        everyElement(allOf(hasLength(greaterThan(0)), contains('foo'))),
        'Expected: every element((an object with length of a value '
        "greater than <0> and contains 'foo')) "
        "Actual: [['foo', 'bar'], ['foo'], []] "
        'Which: has value [] which has length of <0> at index 2');
    shouldFail(
        d,
        everyElement(allOf(contains('foo'), hasLength(greaterThan(0)))),
        "Expected: every element((contains 'foo' and "
        'an object with length of a value greater than <0>)) '
        "Actual: [['foo', 'bar'], ['foo'], []] "
        "Which: has value [] which does not contain 'foo' at index 2");
    shouldFail(
        e,
        everyElement(allOf(contains('foo'), hasLength(greaterThan(0)))),
        "Expected: every element((contains 'foo' and an object with "
        'length of a value greater than <0>)) '
        "Actual: [['foo', 'bar'], ['foo'], 3, []] "
        'Which: has value <3> which is not a string, map or iterable '
        'at index 2');
  });

  test('anyElement', () {
    var d = [1, 2];
    var e = [1, 1, 1];
    shouldPass(d, anyElement(2));
    shouldFail(
        e, anyElement(2), 'Expected: some element <2> Actual: [1, 1, 1]');
    shouldFail('not an iterable', anyElement(2),
        endsWith('not an <Instance of \'Iterable\'>'));
  });

  test('orderedEquals', () {
    shouldPass([null], orderedEquals([null]));
    var d = [1, 2];
    shouldPass(d, orderedEquals([1, 2]));
    shouldFail(
        d,
        orderedEquals([2, 1]),
        'Expected: equals [2, 1] ordered '
        'Actual: [1, 2] '
        'Which: at location [0] is <1> instead of <2>');
    shouldFail('not an iterable', orderedEquals([1]),
        endsWith('not an <Instance of \'Iterable\'>'));
  });

  test('unorderedEquals', () {
    var d = [1, 2];
    shouldPass(d, unorderedEquals([2, 1]));
    shouldFail(
        d,
        unorderedEquals([1]),
        'Expected: equals [1] unordered '
        'Actual: [1, 2] '
        'Which: has too many elements (2 > 1)');
    shouldFail(
        d,
        unorderedEquals([3, 2, 1]),
        'Expected: equals [3, 2, 1] unordered '
        'Actual: [1, 2] '
        'Which: has too few elements (2 < 3)');
    shouldFail(
        d,
        unorderedEquals([3, 1]),
        'Expected: equals [3, 1] unordered '
        'Actual: [1, 2] '
        'Which: has no match for <3> at index 0');
    shouldFail(
        d,
        unorderedEquals([3, 4]),
        'Expected: equals [3, 4] unordered '
        'Actual: [1, 2] '
        'Which: has no match for <3> at index 0'
        ' along with 1 other unmatched');
    shouldFail('not an iterable', unorderedEquals([1]),
        endsWith('not an <Instance of \'Iterable\'>'));
  });

  test('unorderedMatches', () {
    var d = [1, 2];
    shouldPass(d, unorderedMatches([2, 1]));
    shouldPass(d, unorderedMatches([greaterThan(1), greaterThan(0)]));
    shouldPass(d, unorderedMatches([greaterThan(0), greaterThan(1)]));
    shouldPass([2, 1], unorderedMatches([greaterThan(1), greaterThan(0)]));

    shouldPass([2, 1], unorderedMatches([greaterThan(0), greaterThan(1)]));
    // Excersize the case where pairings should get "bumped" multiple times
    shouldPass(
        [0, 1, 2, 3, 5, 6],
        unorderedMatches([
          greaterThan(1), // 6
          equals(2), // 2
          allOf([lessThan(3), isNot(0)]), // 1
          equals(0), // 0
          predicate((int v) => v.isOdd), // 3
          equals(5), // 5
        ]));
    shouldFail(
        d,
        unorderedMatches([greaterThan(0)]),
        'Expected: matches [a value greater than <0>] unordered '
        'Actual: [1, 2] '
        'Which: has too many elements (2 > 1)');
    shouldFail(
        d,
        unorderedMatches([3, 2, 1]),
        'Expected: matches [<3>, <2>, <1>] unordered '
        'Actual: [1, 2] '
        'Which: has too few elements (2 < 3)');
    shouldFail(
        d,
        unorderedMatches([3, 1]),
        'Expected: matches [<3>, <1>] unordered '
        'Actual: [1, 2] '
        'Which: has no match for <3> at index 0');
    shouldFail(
        d,
        unorderedMatches([greaterThan(3), greaterThan(0)]),
        'Expected: matches [a value greater than <3>, a value greater than '
        '<0>] unordered '
        'Actual: [1, 2] '
        'Which: has no match for a value greater than <3> at index 0');
    shouldFail('not an iterable', unorderedMatches([greaterThan(1)]),
        endsWith('not an <Instance of \'Iterable\'>'));
  });

  test('containsAll', () {
    var d = [0, 1, 2];
    shouldPass(d, containsAll([1, 2]));
    shouldPass(d, containsAll([2, 1]));
    shouldPass(d, containsAll([greaterThan(0), greaterThan(1)]));
    shouldPass([2, 1], containsAll([greaterThan(0), greaterThan(1)]));
    shouldFail(
        d,
        containsAll([1, 2, 3]),
        'Expected: contains all of [1, 2, 3] '
        'Actual: [0, 1, 2] '
        'Which: has no match for <3> at index 2');
    shouldFail(
        1,
        containsAll([1]),
        'Expected: contains all of [1] '
        'Actual: <1> '
        "Which: not an <Instance of 'Iterable'>");
    shouldFail(
        [-1, 2],
        containsAll([greaterThan(0), greaterThan(1)]),
        'Expected: contains all of [<a value greater than <0>>, '
        '<a value greater than <1>>] '
        'Actual: [-1, 2] '
        'Which: has no match for a value greater than <1> at index 1');
    shouldFail('not an iterable', containsAll([1, 2, 3]),
        endsWith('not an <Instance of \'Iterable\'>'));
  });

  test('containsAllInOrder', () {
    var d = [0, 1, 0, 2];
    shouldPass(d, containsAllInOrder([1, 2]));
    shouldPass(d, containsAllInOrder([greaterThan(0), greaterThan(1)]));
    shouldFail(
        d,
        containsAllInOrder([2, 1]),
        'Expected: contains in order([2, 1]) '
        'Actual: [0, 1, 0, 2] '
        'Which: did not find a value matching <1> following expected prior '
        'values');
    shouldFail(
        d,
        containsAllInOrder([greaterThan(1), greaterThan(0)]),
        'Expected: contains in order([<a value greater than <1>>, '
        '<a value greater than <0>>]) '
        'Actual: [0, 1, 0, 2] '
        'Which: did not find a value matching a value greater than <0> '
        'following expected prior values');
    shouldFail(
        d,
        containsAllInOrder([1, 2, 3]),
        'Expected: contains in order([1, 2, 3]) '
        'Actual: [0, 1, 0, 2] '
        'Which: did not find a value matching <3> following expected prior '
        'values');
    shouldFail(
        1,
        containsAllInOrder([1]),
        'Expected: contains in order([1]) '
        'Actual: <1> '
        "Which: not an <Instance of 'Iterable'>");
  });

  test('containsOnce', () {
    shouldPass([1, 2, 3, 4], containsOnce(2));
    shouldPass([1, 2, 11, 3], containsOnce(greaterThan(10)));
    shouldFail(
        [1, 2, 3, 4],
        containsOnce(10),
        'Expected: contains once(<10>) '
        'Actual: [1, 2, 3, 4] '
        'Which: did not find a value matching <10>');
    shouldFail(
        [1, 2, 3, 4],
        containsOnce(greaterThan(10)),
        'Expected: contains once(a value greater than <10>) '
        'Actual: [1, 2, 3, 4] '
        'Which: did not find a value matching a value greater than <10>');
    shouldFail(
        [1, 2, 1, 2],
        containsOnce(2),
        'Expected: contains once(<2>) '
        'Actual: [1, 2, 1, 2] '
        'Which: expected only one value matching <2> '
        'but found multiple: <2>, <2>');
    shouldFail(
        [1, 2, 10, 20],
        containsOnce(greaterThan(5)),
        'Expected: contains once(a value greater than <5>) '
        'Actual: [1, 2, 10, 20] '
        'Which: expected only one value matching a value greater than <5> '
        'but found multiple: <10>, <20>');
  });

  test('pairwise compare', () {
    var c = [1, 2];
    var d = [1, 2, 3];
    var e = [1, 4, 9];
    shouldFail(
        'x',
        pairwiseCompare(e, (int e, int a) => a <= e, 'less than or equal'),
        'Expected: pairwise less than or equal [1, 4, 9] '
            "Actual: 'x' "
            "Which: not an <Instance of 'Iterable'>");
    shouldFail(
        c,
        pairwiseCompare(e, (int e, int a) => a <= e, 'less than or equal'),
        'Expected: pairwise less than or equal [1, 4, 9] '
        'Actual: [1, 2] '
        'Which: has length 2 instead of 3');
    shouldPass(
        d, pairwiseCompare(e, (int e, int a) => a <= e, 'less than or equal'));
    shouldFail(
        d,
        pairwiseCompare(e, (int e, int a) => a < e, 'less than'),
        'Expected: pairwise less than [1, 4, 9] '
        'Actual: [1, 2, 3] '
        'Which: has <1> which is not less than <1> at index 0');
    shouldPass(
        d, pairwiseCompare(e, (int e, int a) => a * a == e, 'square root of'));
    shouldFail(
        d,
        pairwiseCompare(e, (int e, int a) => a + a == e, 'double'),
        'Expected: pairwise double [1, 4, 9] '
        'Actual: [1, 2, 3] '
        'Which: has <1> which is not double <1> at index 0');
    shouldFail(
        'not an iterable',
        pairwiseCompare(e, (int e, int a) => a + a == e, 'double'),
        endsWith('not an <Instance of \'Iterable\'>'));
  });

  test('isEmpty', () {
    var d = SimpleIterable(0);
    var e = SimpleIterable(1);
    shouldPass(d, isEmpty);
    shouldFail(
        e,
        isEmpty,
        'Expected: empty '
        'Actual: SimpleIterable:[1]');
  });

  test('isNotEmpty', () {
    var d = SimpleIterable(0);
    var e = SimpleIterable(1);
    shouldPass(e, isNotEmpty);
    shouldFail(
        d,
        isNotEmpty,
        'Expected: non-empty '
        'Actual: SimpleIterable:[]');
  });

  test('contains', () {
    var d = SimpleIterable(3);
    shouldPass(d, contains(2));
    shouldFail(
        d,
        contains(5),
        'Expected: contains <5> '
        'Actual: SimpleIterable:[3, 2, 1] '
        'Which: does not contain <5>');
  });

  test('isSorted', () {
    final sorted = [4, 8, 15, 16, 23, 42];
    final mismatchAtStart = [8, 4, 15, 16, 23, 42];
    final mismatchInMiddle = [4, 8, 16, 15, 23, 42];
    final mismatchAtEnd = [4, 8, 15, 16, 42, 23];
    final singleElement = [42];
    final twoElementsSorted = [42, 143];
    final twoElementsUnsorted = [143, 42];

    shouldPass(sorted, isSorted<num>());
    shouldFail(
        mismatchAtStart,
        isSorted<num>(),
        'Expected: is sorted '
        'Actual: [8, 4, 15, 16, 23, 42] '
        'Which: found elements out of order at <0>: <8> and <4>');
    shouldFail(
        mismatchInMiddle,
        isSorted<num>(),
        'Expected: is sorted '
        'Actual: [4, 8, 16, 15, 23, 42] '
        'Which: found elements out of order at <2>: <16> and <15>');
    shouldFail(
        mismatchAtEnd,
        isSorted<num>(),
        'Expected: is sorted '
        'Actual: [4, 8, 15, 16, 42, 23] '
        'Which: found elements out of order at <4>: <42> and <23>');
    shouldPass(singleElement, isSorted<num>());
    shouldPass(twoElementsSorted, isSorted<num>());
    shouldFail(
        twoElementsUnsorted,
        isSorted<num>(),
        'Expected: is sorted '
        'Actual: [143, 42] '
        'Which: found elements out of order at <0>: <143> and <42>');
  });

  test('isSortedUsing', () {
    final sorted = [1, 2, 3];
    final unsorted = [1, 3, 2];
    final reverseSorted = [3, 2, 1];

    int alwaysEqualCompare(int x, int y) => 0;
    int throwingCompare(int x, int y) => throw Error();

    shouldPass(sorted, isSortedUsing((int x, int y) => x - y));
    shouldFail(
        unsorted,
        isSortedUsing((int x, int y) => x - y),
        'Expected: is sorted '
        'Actual: [1, 3, 2] '
        'Which: found elements out of order at <1>: <3> and <2>');
    shouldPass(reverseSorted, isSortedUsing((int x, int y) => y - x));

    shouldPass(unsorted, isSortedUsing(alwaysEqualCompare));

    shouldFail(
        sorted,
        isSortedUsing(throwingCompare),
        'Expected: is sorted '
        'Actual: [1, 2, 3] '
        'Which: got error <Instance of \'Error\'> at <0> '
        'when comparing <1> and <2>');
  });

  test('isSortedBy', () {
    final sorted = ['y', 'zz', 'bbbb', 'aaaa'];
    final unsorted = ['y', 'bbbb', 'aaaa', 'zz'];
    final sortedDueToSameKey = ['zzz', 'abc', 'def', 'aaa'];

    num throwingKey(String s) => throw Error();

    shouldPass(sorted, isSortedBy<String, num>((String s) => s.length));
    shouldFail(
        unsorted,
        isSortedBy<String, num>((String s) => s.length),
        'Expected: is sorted '
        'Actual: [\'y\', \'bbbb\', \'aaaa\', \'zz\'] '
        'Which: found elements out of order at <2>: \'aaaa\' and \'zz\'');
    shouldPass(
        sortedDueToSameKey, isSortedBy<String, num>((String s) => s.length));

    shouldFail(
        sorted,
        isSortedBy(throwingKey),
        'Expected: is sorted '
        'Actual: [\'y\', \'zz\', \'bbbb\', \'aaaa\'] '
        'Which: got error <Instance of \'Error\'> at <0> '
        'when getting key of \'y\'');
  });

  test('isSortedByCompare', () {
    final sorted = ['aaaa', 'bbbb', 'zz', 'y'];
    final unsorted = ['y', 'bbbb', 'aaaa', 'zz'];

    shouldPass(sorted,
        isSortedByCompare((String s) => s.length, (a, b) => b.compareTo(a)));
    shouldFail(
        unsorted,
        isSortedByCompare((String s) => s.length, (a, b) => b.compareTo(a)),
        'Expected: is sorted '
        'Actual: [\'y\', \'bbbb\', \'aaaa\', \'zz\'] '
        'Which: found elements out of order at <0>: \'y\' and \'bbbb\'');
  });
}
