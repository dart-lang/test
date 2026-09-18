// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../context.dart';

import '../collection_equality.dart';
import 'core.dart';

extension MapChecks<K, V> on Subject<Map<K, V>> {
  /// A [Subject] for the [Map.entries] of the map.
  ///
  /// {@example /example/map/map/entries.dart}
  Subject<Iterable<MapEntry<K, V>>> get entries =>
      has('entries', (m) => m.entries);

  /// A [Subject] for the [Map.keys] of the map.
  ///
  /// {@example /example/map/map/keys.dart}
  Subject<Iterable<K>> get keys => has('keys', (m) => m.keys);

  /// A [Subject] for the [Map.values] of the map.
  ///
  /// {@example /example/map/map/values.dart}
  Subject<Iterable<V>> get values => has('values', (m) => m.values);

  /// A [Subject] for the [Map.length] of the map.
  ///
  /// {@example /example/map/map/length.dart}
  Subject<int> get length => has('length', (m) => m.length);

  /// A [Subject] for the value at [key], which must be present in the map.
  ///
  /// {@example /example/map/map/operator_index.dart}
  Subject<V> operator [](K key) {
    return context.nest(
      () => prefixFirst('contains a value for ', literal(key)),
      addPredicate: (predicateNoun) {
        final l = literal(key).singleOrNull;
        return l != null ? 'has entry <$l: $predicateNoun>' : null;
      },
      (actual) {
        if (!actual.containsKey(key)) {
          return Extracted.rejection(
            which: prefixFirst('does not contain the key ', literal(key)),
          );
        }
        return Extracted.value(actual[key] as V);
      },
    );
  }

  /// Expects that the map is empty.
  ///
  /// {@example /example/map/map/is_empty.dart}
  void get isEmpty {
    context.expect(
      () => const ['is empty'],
      predicateNoun: () => 'an empty map',
      (actual) {
        if (actual.isEmpty) return null;
        return Rejection(which: ['is not empty']);
      },
    );
  }

  /// Expects that the map is not empty.
  ///
  /// {@example /example/map/map/is_not_empty.dart}
  void get isNotEmpty {
    context.expect(
      () => const ['is not empty'],
      predicateNoun: () => 'a non-empty map',
      (actual) {
        if (actual.isNotEmpty) return null;
        return Rejection(which: ['is empty']);
      },
    );
  }

  /// Expects that the map contains [key] according to [Map.containsKey].
  ///
  /// {@example /example/map/map/contains_key.dart}
  void containsKey(K key) {
    context.expect(
      () => prefixFirst('contains key ', literal(key)),
      predicateNoun: () {
        final l = literal(key).singleOrNull;
        return l != null ? 'a map with key $l' : null;
      },
      (actual) {
        if (actual.containsKey(key)) return null;
        return Rejection(
          which: prefixFirst('does not contain key ', literal(key)),
        );
      },
    );
  }

  /// Expects that the map contains some key such that [keyCondition] is
  /// satisfied.
  ///
  /// {@example /example/map/map/contains_key_that.dart}
  void containsKeyThat(Condition<K> keyCondition) {
    context.expect(
      () {
        final conditionDescription = keyCondition.describeSync();
        assert(conditionDescription.isNotEmpty);
        return ['contains a key that:', ...conditionDescription];
      },
      (actual) {
        if (actual.isEmpty) return Rejection(actual: ['an empty map']);
        for (var k in actual.keys) {
          if (keyCondition.softCheckSync(k) == null) return null;
        }
        return Rejection(which: ['contains no matching key']);
      },
    );
  }

  /// Expects that the map contains [value] according to [Map.containsValue].
  ///
  /// {@example /example/map/map/contains_value.dart}
  void containsValue(V value) {
    context.expect(
      () => prefixFirst('contains value ', literal(value)),
      predicateNoun: () {
        final l = literal(value).singleOrNull;
        return l != null ? 'a map with value $l' : null;
      },
      (actual) {
        if (actual.containsValue(value)) return null;
        return Rejection(
          which: prefixFirst('does not contain value ', literal(value)),
        );
      },
    );
  }

  /// Expects that the map contains some value such that [valueCondition] is
  /// satisfied.
  ///
  /// {@example /example/map/map/contains_value_that.dart}
  void containsValueThat(Condition<V> valueCondition) {
    context.expect(
      () {
        final conditionDescription = valueCondition.describeSync();
        assert(conditionDescription.isNotEmpty);
        return ['contains a value that:', ...conditionDescription];
      },
      (actual) {
        if (actual.isEmpty) return Rejection(actual: ['an empty map']);
        for (var v in actual.values) {
          if (valueCondition.softCheckSync(v) == null) return null;
        }
        return Rejection(which: ['contains no matching value']);
      },
    );
  }

  /// Expects that the map contains entries that are deeply equal to the entries
  /// of [expected].
  ///
  /// {@macro deep_collection_equals}
  ///
  /// {@example /example/map/map/deep_equals.dart}
  void deepEquals(Map<Object?, Object?> expected) => context.expect(
    () => prefixFirst('is deeply equal to ', literal(expected)),
    predicateNoun: () => literal(expected).singleOrNull,
    (actual) {
      final which = deepCollectionEquals(actual, expected);
      if (which == null) return null;
      return Rejection(which: which);
    },
  );
}
