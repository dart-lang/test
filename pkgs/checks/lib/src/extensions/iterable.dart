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
      if (actual.isEmpty) return null;
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

  /// Expects that the iterable contains any element such that
  /// [elementCondition] is satisfied.
  void containsThat(void Function(Check<T>) elementCondition) {
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
}
