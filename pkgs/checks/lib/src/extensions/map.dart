// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/context.dart';

import '../collection_equality.dart';
import 'core.dart';

extension MapChecks<K, V> on Subject<Map<K, V>> {
  void hasEntriesWhich(Condition<Iterable<MapEntry<K, V>>> entriesCondition) =>
      has((m) => m.entries, 'entries', entriesCondition);
  void hasKeysWhich(Condition<Iterable<K>> keysCondition) =>
      has((m) => m.keys, 'keys', keysCondition);
  void hasValuesWhich(Condition<Iterable<V>> valuesCondition) =>
      has((m) => m.values, 'values', valuesCondition);
  void hasLengthWhich(Condition<int> lengthCondition) =>
      has((m) => m.length, 'length', lengthCondition);

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

  /// Expects that the map contains [key] according to [Map.containsKey].
  void containsKey(K key, [Condition<V>? valueCondition]) {
    final keyString = literal(key).join(r'\n');
    context.nest<V>(
        'contains key $keyString${valueCondition != null ? ' which reads a value' : ''}',
        (actual) {
      if (actual.containsKey(key)) return Extracted.value(actual[key] as V);
      return Extracted.rejection(which: ['does not contain key $keyString']);
    }, valueCondition);
  }

  /// Expects that the map contains some key such that [keyCondition] is
  /// satisfied.
  void containsKeyThat(Condition<K> keyCondition) {
    context.expect(() {
      final conditionDescription = describe(keyCondition);
      assert(conditionDescription.isNotEmpty);
      return [
        'contains a key that:',
        ...conditionDescription,
      ];
    }, (actual) {
      if (actual.isEmpty) return Rejection(actual: ['an empty map']);
      for (var k in actual.keys) {
        if (softCheck(k, keyCondition) == null) return null;
      }
      return Rejection(which: ['Contains no matching key']);
    });
  }

  /// Expects that the map contains [value] according to [Map.containsValue].
  void containsValue(V value) {
    final valueString = literal(value).join(r'\n');
    context.expect(() => ['contains value $valueString'], (actual) {
      if (actual.containsValue(value)) return null;
      return Rejection(which: ['does not contain value $valueString']);
    });
  }

  /// Expects that the map contains some value such that [valueCondition] is
  /// satisfied.
  void containsValueThat(Condition<V> valueCondition) {
    context.expect(() {
      final conditionDescription = describe(valueCondition);
      assert(conditionDescription.isNotEmpty);
      return [
        'contains a value that:',
        ...conditionDescription,
      ];
    }, (actual) {
      if (actual.isEmpty) return Rejection(actual: ['an empty map']);
      for (var v in actual.values) {
        if (softCheck(v, valueCondition) == null) return null;
      }
      return Rejection(which: ['Contains no matching value']);
    });
  }

  /// Expects that the map contains entries that are deeply equal to the entries
  /// of [expected].
  ///
  /// {@macro deep_collection_equals}
  void deepEquals(Map<Object?, Object?> expected) => context
          .expect(() => prefixFirst('is deeply equal to ', literal(expected)),
              (actual) {
        final which = deepCollectionEquals(actual, expected);
        if (which == null) return null;
        return Rejection(which: which);
      });
}
