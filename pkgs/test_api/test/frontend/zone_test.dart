// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

void main() {
  const group1 = 'group 1';
  const test11 = 'test 1.1';
  const test12 = 'test 1.2';
  const group2 = 'group 2';
  const test21 = 'test 2.1';
  const test22 = 'test 2.2';
  const keys = [group1, test11, test12, group2, test21, test22];

  void checkIn(List<String> expected, {bool inTest = true}) {
    for (var key in keys) {
      var isExpected = expected.contains(key);
      var expectedValue = isExpected ? key : null;
      var actual = Zone.current[key];
      var failureMessage = '${isExpected ? 'not ' : ''}in $key zone';
      if (inTest) {
        expect(actual, expectedValue, reason: failureMessage);
      } else {
        if (actual != expectedValue) {
          throw StateError(failureMessage);
        }
      }
    }
  }

  runZoned(zoneValues: {group1: group1}, () {
    group('group 1', () {
      setUp(() {
        checkIn(const [group1], inTest: false);
      });
      tearDown(() {
        checkIn(const [group1], inTest: false);
      });
      setUpAll(() {
        checkIn(const [group1], inTest: false);
      });
      tearDownAll(() {
        checkIn(const [group1], inTest: false);
      });
      runZoned(zoneValues: {test11: test11}, () {
        setUp(() {
          checkIn(const [group1, test11], inTest: false);
        });
        tearDown(() {
          checkIn(const [group1, test11], inTest: false);
        });
        setUpAll(() {
          checkIn(const [group1, test11], inTest: false);
        });
        tearDownAll(() {
          checkIn(const [group1, test11], inTest: false);
        });

        test('test 1.1', () {
          checkIn(const [group1, test11]);
        });
      });
      runZoned(zoneValues: {test12: test12}, () {
        test('test 1.2', () {
          checkIn(const [group1, test12]);
        });
      });
      test('test 1.3', () {
        checkIn(const [group1]);
      });
    });
  });

  // Same with no setup.
  runZoned(zoneValues: {group2: group2}, () {
    group('group 2', () {
      runZoned(zoneValues: {test21: test21}, () {
        test('test 2.1', () {
          checkIn(const [group2, test21]);
        });
      });
      runZoned(zoneValues: {test22: test22}, () {
        test('test 2.2', () {
          checkIn(const [group2, test22]);
        });
      });
      test('test 2.3', () {
        checkIn(const [group2]);
      });
    });
  });

  group('group 3', () {
    test('test 3.1', () {
      checkIn(const []);
    });
  });

  test('test 4', () {
    checkIn(const []);
  });
}
