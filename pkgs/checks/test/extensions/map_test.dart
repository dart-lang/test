// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

const _testMap = {
  'a': 1,
  'b': 2,
};

void main() {
  test('length', () {
    check(_testMap).length.equals(2);
  });
  test('entries', () {
    check(_testMap).entries.any(
          (it) => it
            ..has((p0) => p0.key, 'key').equals('a')
            ..has((p0) => p0.value, 'value').equals(1),
        );
  });
  test('keys', () {
    check(_testMap).keys.contains('a');
  });
  test('values', () {
    check(_testMap).values.contains(1);
  });
  test('can be described failing compared to another large map', () {
    const expected = {
      1: -5,
      2: -4,
      3: -4,
      4: -3,
      5: -3,
      6: -2,
      7: -2,
      8: -1,
      9: -1,
      10: 0,
      11: 0,
      12: 1,
      13: 1,
      14: 2,
      15: 2,
      16: 3,
      17: 3,
      18: 4,
      19: 4,
      20: 5,
      21: 5,
      22: 6,
      23: 6,
      24: 7,
      25: 7,
      26: 8,
    };
    final actual = {
      1: -4,
      2: -4,
      3: -3,
      4: -3,
      5: -2,
      6: -2,
      7: -1,
      8: -1,
      9: 0,
      10: 0,
      11: 0,
      12: 1,
      13: 1,
      14: 2,
      15: 2,
      16: 3,
      17: 3,
      18: 4,
      19: 4,
      20: 5,
      21: 5,
      22: 6,
      23: 6,
      24: 7,
      25: 7,
      26: 8,
    };
    check(actual).not((a) => a.deepEquals(expected));
  });

  group('operator []', () {
    test('succeeds for a key that exists', () {
      check(_testMap)['a'].equals(1);
    });
    test('fails for a missing key', () {
      check(_testMap).isRejectedBy((it) => it['z'],
          which: ["does not contain the key 'z'"]);
    });
    test('can be described', () {
      check((Subject<Map<String, Object>> it) => it['some\nlong\nkey'])
          .description
          .deepEquals([
        "  contains a value for 'some",
        '  long',
        "  key'",
      ]);
      check((Subject<Map<String, Object>> it) =>
          it['some\nlong\nkey'].equals(1)).description.deepEquals([
        "  contains a value for 'some",
        '  long',
        "  key' that:",
        '    equals <1>',
      ]);
    });
  });
  test('isEmpty', () {
    check(<String, int>{}).isEmpty();
    check(_testMap).isRejectedBy((it) => it.isEmpty(), which: ['is not empty']);
  });
  test('isNotEmpty', () {
    check(_testMap).isNotEmpty();
    check(<Object, Object>{})
        .isRejectedBy((it) => it.isNotEmpty(), which: ['is not empty']);
  });
  group('containsKey', () {
    test('succeeds for a key that exists', () {
      check(_testMap).containsKey('a');
    });
    test('fails for a missing key', () {
      check(_testMap).isRejectedBy(
        (it) => it.containsKey('c'),
        which: ["does not contain key 'c'"],
      );
    });
    test('can be described', () {
      check((Subject<Map<String, Object>> it) =>
          it.containsKey('some\nlong\nkey')).description.deepEquals([
        "  contains key 'some",
        '  long',
        "  key'",
      ]);
    });
  });
  test('containsKeyThat', () {
    check(_testMap).containsKeyThat((it) => it.equals('a'));
    check(_testMap).isRejectedBy(
      (it) => it.containsKeyThat((it) => it.equals('c')),
      which: ['Contains no matching key'],
    );
  });
  group('containsValue', () {
    test('succeeds for happy case', () {
      check(_testMap).containsValue(1);
    });
    test('fails for missing value', () {
      check(_testMap).isRejectedBy(
        (it) => it.containsValue(3),
        which: ['does not contain value <3>'],
      );
    });
    test('can be described', () {
      check((Subject<Map<String, String>> it) =>
          it.containsValue('some\nlong\nkey')).description.deepEquals([
        "  contains value 'some",
        '  long',
        "  key'",
      ]);
    });
  });
  test('containsValueThat', () {
    check(_testMap).containsValueThat((it) => it.equals(1));
    check(_testMap).isRejectedBy(
      (it) => it.containsValueThat((it) => it.equals(3)),
      which: ['Contains no matching value'],
    );
  });
}
