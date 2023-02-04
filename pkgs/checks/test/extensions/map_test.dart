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
          it()
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

  group('operator []', () {
    test('succeeds for a key that exists', () {
      check(_testMap)['a'].equals(1);
    });
    test('fails for a missing key', () {
      check(_testMap)
          .isRejectedBy(it()..['z'], which: ["does not contain the key 'z'"]);
    });
    test('can be described', () {
      check(it<Map<String, Object>>()..['some\nlong\nkey'])
          .description
          .deepEquals([
        "  contains a value for 'some",
        '  long',
        "  key'",
      ]);
      check(it<Map<String, Object>>()..['some\nlong\nkey'].equals(1))
          .description
          .deepEquals([
        "  contains a value for 'some",
        '  long',
        "  key' that:",
        '    equals <1>',
      ]);
    });
  });
  test('isEmpty', () {
    check(<String, int>{}).isEmpty();
    check(_testMap).isRejectedBy(it()..isEmpty(), which: ['is not empty']);
  });
  test('isNotEmpty', () {
    check(_testMap).isNotEmpty();
    check({}).isRejectedBy(it()..isNotEmpty(), which: ['is not empty']);
  });
  group('containsKey', () {
    test('succeeds for a key that exists', () {
      check(_testMap).containsKey('a');
    });
    test('fails for a missing key', () {
      check(_testMap).isRejectedBy(
        it()..containsKey('c'),
        which: ["does not contain key 'c'"],
      );
    });
    test('can be described', () {
      check(it<Map<String, Object>>()..containsKey('some\nlong\nkey'))
          .description
          .deepEquals([
        "  contains key 'some",
        '  long',
        "  key'",
      ]);
    });
  });
  test('containsKeyThat', () {
    check(_testMap).containsKeyThat(it()..equals('a'));
    check(_testMap).isRejectedBy(
      it()..containsKeyThat(it()..equals('c')),
      which: ['Contains no matching key'],
    );
  });
  group('containsValue', () {
    test('succeeds for happy case', () {
      check(_testMap).containsValue(1);
    });
    test('fails for missing value', () {
      check(_testMap).isRejectedBy(
        it()..containsValue(3),
        which: ['does not contain value <3>'],
      );
    });
    test('can be described', () {
      check(it<Map<String, String>>()..containsValue('some\nlong\nkey'))
          .description
          .deepEquals([
        "  contains value 'some",
        '  long',
        "  key'",
      ]);
    });
  });
  test('containsValueThat', () {
    check(_testMap).containsValueThat(it()..equals(1));
    check(_testMap).isRejectedBy(
      it()..containsValueThat(it()..equals(3)),
      which: ['Contains no matching value'],
    );
  });
}
