// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/context.dart';

import 'core.dart' show HasField;

extension IterableChecks<T> on Check<Iterable<T>> {
  Check<int> get length => has((l) => l.length, 'length');
  Check<T> get first => has((l) => l.first, 'first element');
  Check<T> get last => has((l) => l.last, 'last element');
  Check<T> get single => has((l) => l.single, 'single element');

  void isEmpty() {
    context.expect(() => const ['is empty'], (actual) {
      if (actual.isEmpty) return null;
      return Rejection(actual: literal(actual), which: ['is not empty']);
    });
  }

  void isNotEmpty() {
    context.expect(() => const ['is not empty'], (actual) {
      if (actual.isNotEmpty) return null;
      return Rejection(actual: literal(actual), which: ['is not empty']);
    });
  }

  /// Expects that the iterable contains [element] according to
  /// [Iterable.contains].
  void contains(T element) {
    context.expect(() {
      return [
        'contains ${literal(element)}',
      ];
    }, (actual) {
      if (actual.isEmpty) return Rejection(actual: 'an empty iterable');
      if (actual.contains(element)) return null;
      return Rejection(
          actual: literal(actual),
          which: ['does not contain ${literal(element)}']);
    });
  }

  /// Expects that the iterable contains at least on element such that
  /// [elementCondition] is satisfied.
  void any(void Function(Check<T>) elementCondition) {
    context.expect(() {
      final conditionDescription = describe(elementCondition);
      assert(conditionDescription.isNotEmpty);
      return [
        'contains a value that:',
        ...conditionDescription,
      ];
    }, (actual) {
      if (actual.isEmpty) return Rejection(actual: 'an empty iterable');
      for (var e in actual) {
        if (softCheck(e, elementCondition) == null) return null;
      }
      return Rejection(
          actual: '${literal(actual)}',
          which: ['Contains no matching element']);
    });
  }

  /// Expects there are no elements in the iterable which fail to satisfy
  /// [elementCondition].
  ///
  /// Empty iterables will pass always pass this check.
  void every(void Function(Check<T>) elementCondition) {
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
        return Rejection(actual: literal(actual), which: [
          'has an element at index $i that:',
          ...indent(failure.detail.actual.skip(1)),
          ...indent(['Actual: ${failure.rejection.actual}'],
              failure.detail.depth + 1),
          if (which != null && which.isNotEmpty)
            ...indent(prefixFirst('Which: ', which), failure.detail.depth + 1),
        ]);
      }
      return null;
    });
  }
}
