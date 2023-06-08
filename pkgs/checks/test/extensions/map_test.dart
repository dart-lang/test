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
    check(_testMap).hasLengthWhich(it()..equals(2));
  });
  test('entries', () {
    check(_testMap).hasEntriesWhich(it()
      ..any(
        it()
          ..has((p0) => p0.key, 'key').which(it()..equals('a'))
          ..has((p0) => p0.value, 'value').which(it()..equals(1)),
      ));
  });
  test('keys', () {
    check(_testMap).hasKeysWhich(it()..contains('a'));
  });
  test('values', () {
    check(_testMap).hasValuesWhich(it()..contains(1));
  });

  test('isEmpty', () {
    check(<String, int>{}).isEmpty();
    check(_testMap).isRejectedBy(it()..isEmpty(), which: ['is not empty']);
  });
  test('isNotEmpty', () {
    check(_testMap).isNotEmpty();
    check({}).isRejectedBy(it()..isNotEmpty(), which: ['is not empty']);
  });
  test('containsKey', () {
    check(_testMap).containsKey('a');
    check(_testMap).containsKey('a', it()..equals(1));

    check(_testMap).isRejectedBy(
      it()..containsKey('c'),
      which: ["does not contain key 'c'"],
    );
    check(_testMap).isRejectedBy(
      it()..containsKey('a', it()..equals(2)),
      actual: ['<1>'],
      which: ['are not equal'],
    );
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
          .hasDescriptionWhich(it()
            ..deepEquals([
              "  contains value 'some",
              '  long',
              "  key'",
            ]));
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
