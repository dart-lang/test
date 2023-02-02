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

  test('operator []', () async {
    check(_testMap)['a'].equals(1);
    check(_testMap)
        .isRejectedBy(it()..['z'], which: ['does not contain the key \'z\'']);
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

    check(_testMap).isRejectedBy(
      it()..containsKey('c'),
      which: ["does not contain key 'c'"],
    );
  });
  test('containsKeyThat', () {
    check(_testMap).containsKeyThat(it()..equals('a'));
    check(_testMap).isRejectedBy(
      it()..containsKeyThat(it()..equals('c')),
      which: ['Contains no matching key'],
    );
  });
  test('containsValue', () {
    check(_testMap).containsValue(1);
    check(_testMap).isRejectedBy(
      it()..containsValue(3),
      which: ['does not contain value <3>'],
    );
  });
  test('containsValueThat', () {
    check(_testMap).containsValueThat(it()..equals(1));
    check(_testMap).isRejectedBy(
      it()..containsValueThat(it()..equals(3)),
      which: ['Contains no matching value'],
    );
  });
}
