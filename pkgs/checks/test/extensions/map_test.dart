// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

const _testMap = {
  'a': 1,
  'b': 2,
};

const _testMapString = '{a: 1, b: 2}';

void main() {
  test('length', () {
    checkThat(_testMap).length.equals(2);
  });
  test('entries', () {
    checkThat(_testMap).entries.any(
          (p0) => p0
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

  test('index operator', () async {
    checkThat(_testMap)['a'].equals(1);
    checkThat(softCheck<Map<String, int>>(_testMap, (c) => c['z']))
        .isARejection(which: ['does not contain the key \'z\'']);
  });

  test('isEmpty', () {
    checkThat(<String, int>{}).isEmpty();
    checkThat(
      softCheck<Map<String, int>>(_testMap, (p0) => p0.isEmpty()),
    ).isARejection(actual: _testMapString, which: ['is not empty']);
  });

  test('isNotEmpty', () {
    checkThat(_testMap).isNotEmpty();
    checkThat(
      softCheck<Map<String, int>>({}, (p0) => p0.isNotEmpty()),
    ).isARejection(actual: '{}', which: ['is not empty']);
  });

  test('containsKey', () {
    checkThat(_testMap).containsKey('a');

    checkThat(
      softCheck<Map<String, int>>(_testMap, (p0) => p0.containsKey('c')),
    ).isARejection(
      actual: _testMapString,
      which: ["does not contain key 'c'"],
    );
  });
  test('containsKeyThat', () {
    checkThat(_testMap).containsKeyThat((p0) => p0.equals('a'));
    checkThat(
      softCheck<Map<String, int>>(
        _testMap,
        (p0) => p0.containsKeyThat((p1) => p1.equals('c')),
      ),
    ).isARejection(
      actual: _testMapString,
      which: ['Contains no matching key'],
    );
  });
  test('containsValue', () {
    checkThat(_testMap).containsValue(1);
    checkThat(
      softCheck<Map<String, int>>(_testMap, (p0) => p0.containsValue(3)),
    ).isARejection(
      actual: _testMapString,
      which: ['does not contain value <3>'],
    );
  });
  test('containsValueThat', () {
    checkThat(_testMap).containsValueThat((p0) => p0.equals(1));
    checkThat(
      softCheck<Map<String, int>>(
          _testMap, (p0) => p0.containsValueThat((p1) => p1.equals(3))),
    ).isARejection(
      actual: _testMapString,
      which: ['Contains no matching value'],
    );
  });
}
