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
    _testMap.must.haveLength.equal(2);
  });
  test('entries', () {
    _testMap.must.haveEntries.containElementWhich(
      would()
        ..have((p0) => p0.key, 'key').equal('a')
        ..have((p0) => p0.value, 'value').equal(1),
    );
  });
  test('keys', () {
    _testMap.must.haveKeys.contain('a');
  });
  test('values', () {
    _testMap.must.haveValues.contain(1);
  });

  test('operator []', () async {
    _testMap.must['a'].equal(1);
    _testMap.must.beRejectedBy(would()..['z'],
        which: ['does not contain the key \'z\'']);
  });
  test('isEmpty', () {
    (<String, int>{}).must.beEmpty();
    _testMap.must.beRejectedBy(would()..beEmpty(), which: ['is not empty']);
  });
  test('isNotEmpty', () {
    _testMap.must.beNotEmpty();
    ({}).must.beRejectedBy(would()..beNotEmpty(), which: ['is not empty']);
  });
  test('containsKey', () {
    _testMap.must.containKey('a');

    _testMap.must.beRejectedBy(
      would()..containKey('c'),
      which: ["does not contain key 'c'"],
    );
  });
  test('containsKeyThat', () {
    _testMap.must.containKeyWhich(would()..equal('a'));
    _testMap.must.beRejectedBy(
      would()..containKeyWhich(would()..equal('c')),
      which: ['Contains no matching key'],
    );
  });
  test('containsValue', () {
    _testMap.must.containValue(1);
    _testMap.must.beRejectedBy(
      would()..containValue(3),
      which: ['does not contain value <3>'],
    );
  });
  test('containsValueThat', () {
    _testMap.must.containValueWhich(would()..equal(1));
    _testMap.must.beRejectedBy(
      would()..containValueWhich(would()..equal(3)),
      which: ['Contains no matching value'],
    );
  });
}
