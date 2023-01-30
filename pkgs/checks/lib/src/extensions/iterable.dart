// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/context.dart';

import '../collection_equality.dart';
import 'core.dart';

extension IterableChecks<T> on Subject<Iterable<T>> {
  Subject<int> get length => has((l) => l.length, 'length');
  Subject<T> get first => has((l) => l.first, 'first element');
  Subject<T> get last => has((l) => l.last, 'last element');
  Subject<T> get single => has((l) => l.single, 'single element');

  void isEmpty() {
    context.expect(() => const ['is empty'], (actual) {
      if (actual.isEmpty) return null;
      return Rejection(which: ['is not empty']);
    });
  }

  void isNotEmpty() {
    context.expect(() => const ['is not empty'], (actual) {
      if (actual.isNotEmpty) return null;
      return Rejection(which: ['is not empty']);
    });
  }

  /// Expects that the iterable contains [element] according to
  /// [Iterable.contains].
  void contains(T element) {
    context.expect(() {
      return prefixFirst('contains ', literal(element));
    }, (actual) {
      if (actual.isEmpty) return Rejection(actual: ['an empty iterable']);
      if (actual.contains(element)) return null;
      return Rejection(
          which: prefixFirst('does not contain ', literal(element)));
    });
  }

  /// Expects that the iterable contains a value matching each expected value
  /// from [elelements] in the given order, with any extra elements between
  /// them.
  ///
  /// For example, the following will succeed:
  ///
  /// ```dart
  /// check([1, 0, 2, 0, 3]).containsInOrder([1, 2, 3]);
  /// ```
  ///
  /// Values in [elements] may be a `T`, a `Condition<T>`, or a
  /// `Condition<dynamic>`. If an expectation is a [Condition] it will be
  /// checked against the actual values, and any other expectations, including
  /// those that are not a `T` or a `Condition`, will be compared with the
  /// equality operator.
  ///
  /// ```dart
  /// check([1, 0, 2, 0, 3])
  ///   .containsInOrder([1, it<int>()..isGreaterThan(1), 3]);
  /// ```
  void containsInOrder(Iterable<Object?> elements) {
    context.expect(() => prefixFirst('contains, in order: ', literal(elements)),
        (actual) {
      final expected = elements.toList();
      if (expected.isEmpty) {
        throw ArgumentError('expected may not be empty');
      }
      var expectedIndex = 0;
      for (final element in actual) {
        final currentExpected = expected[expectedIndex];
        final matches = currentExpected is Condition<T>
            ? softCheck(element, currentExpected) == null
            : currentExpected is Condition<dynamic>
                ? softCheck(element, currentExpected) == null
                : currentExpected == element;
        if (matches && ++expectedIndex >= expected.length) return null;
      }
      return Rejection(which: [
        ...prefixFirst(
            'did not have an element matching the expectation at index '
            '$expectedIndex ',
            literal(expected[expectedIndex])),
      ]);
    });
  }

  /// Expects that the iterable contains at least on element such that
  /// [elementCondition] is satisfied.
  void any(Condition<T> elementCondition) {
    context.expect(() {
      final conditionDescription = describe(elementCondition);
      assert(conditionDescription.isNotEmpty);
      return [
        'contains a value that:',
        ...conditionDescription,
      ];
    }, (actual) {
      if (actual.isEmpty) return Rejection(actual: ['an empty iterable']);
      for (var e in actual) {
        if (softCheck(e, elementCondition) == null) return null;
      }
      return Rejection(which: ['Contains no matching element']);
    });
  }

  /// Expects there are no elements in the iterable which fail to satisfy
  /// [elementCondition].
  ///
  /// Empty iterables will pass always pass this expectation.
  void every(Condition<T> elementCondition) {
    context.expect(() {
      final conditionDescription = describe(elementCondition);
      assert(conditionDescription.isNotEmpty);
      return [
        'only has values that:',
        ...conditionDescription,
      ];
    }, (actual) {
      final iterator = actual.iterator;
      for (var i = 0; iterator.moveNext(); i++) {
        final element = iterator.current;
        final failure = softCheck(element, elementCondition);
        if (failure == null) continue;
        final which = failure.rejection.which;
        return Rejection(which: [
          'has an element at index $i that:',
          ...indent(failure.detail.actual.skip(1)),
          ...indent(prefixFirst('Actual: ', failure.rejection.actual),
              failure.detail.depth + 1),
          if (which != null && which.isNotEmpty)
            ...indent(prefixFirst('Which: ', which), failure.detail.depth + 1),
        ]);
      }
      return null;
    });
  }

  /// Expects that the iterable contains elements that are deeply equal to the
  /// elements of [expected].
  ///
  /// {@macro deep_collection_equals}
  void deepEquals(Iterable<Object?> expected) => context
          .expect(() => prefixFirst('is deeply equal to ', literal(expected)),
              (actual) {
        final which = deepCollectionEquals(actual, expected);
        if (which == null) return null;
        return Rejection(which: which);
      });

  /// Expects that the iterable contains elements which equal those of
  /// [expected] in any order.
  ///
  /// Should not be used for very large collections, runtime is O(n^2.5) in the
  /// worst case where the iterables contain many equal elements, and O(n^2) in
  /// more typical cases.
  void unorderedEquals(Iterable<T> expected) {
    context.expect(() => prefixFirst('unordered equals ', literal(expected)),
        (actual) {
      final which = unorderedCompare(
        actual,
        expected,
        (actual, expected) => expected == actual,
        (expected, index, count) => [
          ...prefixFirst(
              'has no element equal to the expected element at index '
              '$index: ',
              literal(expected)),
          if (count > 1) 'or ${count - 1} other elements',
        ],
        (actual, index, count) => [
          ...prefixFirst(
              'has an unexpected element at index $index: ', literal(actual)),
          if (count > 1) 'and ${count - 1} other unexpected elements',
        ],
      );
      if (which == null) return null;
      return Rejection(which: which);
    });
  }

  /// Expects that the iterable contains elements which match all conditions of
  /// [expected] in any order.
  ///
  /// Should not be used for very large collections, runtime is O(n^2.5) in the
  /// worst case where conditions match many elements, and O(n^2) in more
  /// typical cases.
  void unorderedMatches(Iterable<Condition<T>> expected) {
    context.expect(() => prefixFirst('unordered matches ', literal(expected)),
        (actual) {
      final which = unorderedCompare(
        actual,
        expected,
        (actual, expected) => softCheck(actual, expected) == null,
        (expected, index, count) => [
          'has no element matching the condition at index $index:',
          ...describe(expected),
          if (count > 1) 'or ${count - 1} other conditions',
        ],
        (actual, index, count) => [
          ...prefixFirst(
              'has an unmatched element at index $index: ', literal(actual)),
          if (count > 1) 'and ${count - 1} other unmatched elements',
        ],
      );
      if (which == null) return null;
      return Rejection(which: which);
    });
  }

  /// Expects that the iterable contains elements that correspond by the
  /// [elementCondition] exactly to each element in [expected].
  ///
  /// Fails if the iterable has a different length than [expected].
  ///
  /// For each element in the iterable, calls [elementCondition] with the
  /// corresponding element from [expected] to get the specific condition for
  /// that index.
  ///
  /// [description] is used in the Expected clause. It should be a predicate
  /// without the object, for example with the description 'is less than' the
  /// full expectation will be: "pairwise is less than $expected"
  void pairwiseComparesTo<S>(List<S> expected,
      Condition<T> Function(S) elementCondition, String description) {
    context.expect(() {
      return prefixFirst('pairwise $description ', literal(expected));
    }, (actual) {
      final iterator = actual.iterator;
      for (var i = 0; i < expected.length; i++) {
        final expectedValue = expected[i];
        if (!iterator.moveNext()) {
          return Rejection(which: [
            'has too few elements, there is no element to match at index $i'
          ]);
        }
        final actualValue = iterator.current;
        final failure = softCheck(actualValue, elementCondition(expectedValue));
        if (failure == null) continue;
        final innerDescription = describe<T>(elementCondition(expectedValue));
        final which = failure.rejection.which;
        return Rejection(which: [
          'does not have an element at index $i that:',
          ...innerDescription,
          ...prefixFirst(
              'Actual element at index $i: ', failure.rejection.actual),
          if (which != null) ...prefixFirst('Which: ', which),
        ]);
      }
      if (!iterator.moveNext()) return null;
      return Rejection(which: [
        'has too many elements, expected exactly ${expected.length}'
      ]);
    });
  }
}
