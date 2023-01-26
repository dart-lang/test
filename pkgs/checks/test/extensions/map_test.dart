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
    checkThat(_testMap).length.equals(2);
  });
  test('entries', () {
    checkThat(_testMap).entries.any(
          it()
            ..has((p0) => p0.key, 'key').equals('a')
            ..has((p0) => p0.value, 'value').equals(1),
        );
  });
  test('keys', () {
    checkThat(_testMap).keys.contains('a');
  });
  test('values', () {
    checkThat(_testMap).values.contains(1);
  });

  test('operator []', () async {
    checkThat(_testMap)['a'].equals(1);
    checkThat(_testMap)
        .isRejectedBy(it()..['z'], which: ['does not contain the key \'z\'']);
  });
  test('isEmpty', () {
    checkThat(<String, int>{}).isEmpty();
    checkThat(_testMap).isRejectedBy(it()..isEmpty(), which: ['is not empty']);
  });
  test('isNotEmpty', () {
    checkThat(_testMap).isNotEmpty();
    checkThat({}).isRejectedBy(it()..isNotEmpty(), which: ['is not empty']);
  });
  test('containsKey', () {
    checkThat(_testMap).containsKey('a');

    checkThat(_testMap).isRejectedBy(
      it()..containsKey('c'),
      which: ["does not contain key 'c'"],
    );
  });
  test('containsKeyThat', () {
    checkThat(_testMap).containsKeyThat(it()..equals('a'));
    checkThat(_testMap).isRejectedBy(
      it()..containsKeyThat(it()..equals('c')),
      which: ['Contains no matching key'],
    );
  });
  test('containsValue', () {
    checkThat(_testMap).containsValue(1);
    checkThat(_testMap).isRejectedBy(
      it()..containsValue(3),
      which: ['does not contain value <3>'],
    );
  });
  test('containsValueThat', () {
    checkThat(_testMap).containsValueThat(it()..equals(1));
    checkThat(_testMap).isRejectedBy(
      it()..containsValueThat(it()..equals(3)),
      which: ['Contains no matching value'],
    );
  });
}
