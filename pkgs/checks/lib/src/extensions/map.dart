import 'package:checks/context.dart';

import 'core.dart' show HasField;

extension MapChecks<K, V> on Check<Map<K, V>> {
  Check<Iterable<MapEntry<K, V>>> get entries =>
      has((m) => m.entries, 'entries');
  Check<Iterable<K>> get keys => has((m) => m.keys, 'keys');
  Check<Iterable<V>> get values => has((m) => m.values, 'values');
  Check<int> get length => has((m) => m.length, 'length');

  /// Expects that the map contains [key] according to [Map.containsKey].
  void containsKey(K key) {
    context.expect(() => ['contains key ${literal(key)}'], (actual) {
      if (actual.containsKey(key)) return null;
      return Rejection(
          actual: literal(actual),
          which: ['does not contain key ${literal(key)}']);
    });
  }

  /// Expects that the map contains some key such that [keyCondition] is
  /// satisfied.
  void containsKeyThat(void Function(Check<K>) keyCondition) {
    context.expect(() {
      final conditionDescription = describe(keyCondition);
      assert(conditionDescription.isNotEmpty);
      return [
        'contains a key that:',
        ...conditionDescription,
      ];
    }, (actual) {
      if (actual.isEmpty) return Rejection(actual: 'an empty map');
      for (var k in actual.keys) {
        if (softCheck(k, keyCondition) == null) return null;
      }
      return Rejection(
          actual: '${literal(actual)}', which: ['Contains no matching key']);
    });
  }

  /// Expects that the map contains [value] according to [Map.containsValue].
  void containsValue(V value) {
    context.expect(() => ['contains value ${literal(value)}'], (actual) {
      if (actual.containsValue(value)) return null;
      return Rejection(
          actual: literal(actual),
          which: ['does not contain value ${literal(value)}']);
    });
  }

  /// Expects that the map contains some value such that [valueCondition] is
  /// satisfied.
  void containsValueThat(void Function(Check<V>) valueCondition) {
    context.expect(() {
      final conditionDescription = describe(valueCondition);
      assert(conditionDescription.isNotEmpty);
      return [
        'contains a value that:',
        ...conditionDescription,
      ];
    }, (actual) {
      if (actual.isEmpty) return Rejection(actual: 'an empty map');
      for (var v in actual.values) {
        if (softCheck(v, valueCondition) == null) return null;
      }
      return Rejection(
          actual: '${literal(actual)}', which: ['Contains no matching value']);
    });
  }
}
