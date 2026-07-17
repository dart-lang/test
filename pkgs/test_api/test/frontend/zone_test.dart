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
  final mainZone = Zone.current;

  void checkHasValues(List<String> expected, {bool inTest = true}) {
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

  /// Checks that each zone in [zones] is an ancestor of [Zone.current].
  void checkIn(List<Zone> zones, {bool inTest = true}) {
    outer:
    for (var zone in zones) {
      Zone? zoneCursor = Zone.current;
      while (zoneCursor != null) {
        if (identical(zone, zoneCursor)) {
          // Found.
          continue outer;
        }
        zoneCursor = zoneCursor.parent;
      }
      var message = 'Not in zone $zone(#${zone.hashCode.toRadixString(16)}';
      if (inTest) {
        fail(message);
      } else {
        throw StateError(message);
      }
    }
  }

  runZoned(zoneValues: {group1: group1}, () {
    final groupZone1 = Zone.current;
    group('group 1', () {
      void expectGroup1({bool inTest = false}) {
        checkIn([mainZone, groupZone1], inTest: inTest);
        checkHasValues(const [group1], inTest: inTest);
      }

      expectGroup1(inTest: false);
      setUp(() {
        expectGroup1(inTest: false);
      });
      tearDown(() {
        expectGroup1(inTest: false);
      });
      setUpAll(() {
        expectGroup1(inTest: false);
      });
      tearDownAll(() {
        expectGroup1(inTest: false);
      });
      runZoned(zoneValues: {test11: test11}, () {
        final testZone11 = Zone.current;
        void expectTest11({bool inTest = false}) {
          checkIn([mainZone, groupZone1, testZone11], inTest: inTest);
          checkHasValues(const [group1, test11], inTest: inTest);
        }

        setUp(() {
          expectTest11(inTest: false);
        });
        tearDown(() {
          expectTest11(inTest: false);
        });
        setUpAll(() {
          expectTest11(inTest: false);
        });
        tearDownAll(() {
          expectTest11(inTest: false);
        });

        test('test 1.1', () {
          expectTest11(inTest: true);
        });
      });
      runZoned(zoneValues: {test12: test12}, () {
        final testZone12 = Zone.current;
        test('test 1.2', () {
          checkIn([mainZone, groupZone1, testZone12]);
          checkHasValues(const [group1, test12]);
        });
      });
      test('test 1.3', () {
        checkIn([mainZone, groupZone1]);
        checkHasValues(const [group1]);
      });
    });
  });

  // Same with no setup.
  runZoned(zoneValues: {group2: group2}, () {
    final groupZone2 = Zone.current;
    group('group 2', () {
      checkIn([mainZone, groupZone2], inTest: false);
      runZoned(zoneValues: {test21: test21}, () {
        final testZone21 = Zone.current;
        test('test 2.1', () {
          checkIn([mainZone, groupZone2, testZone21], inTest: true);
          checkHasValues(const [group2, test21]);
        });
      });
      runZoned(zoneValues: {test22: test22}, () {
        checkIn([mainZone, groupZone2], inTest: false);
        test('test 2.2', () {
          checkHasValues(const [group2, test22]);
        });
      });
      test('test 2.3', () {
        checkHasValues(const [group2]);
      });
    });
  });

  group('group 3', () {
    test('test 3.1', () {
      checkHasValues(const []);
    });
  });

  test('test 4', () {
    checkHasValues(const []);
  });
}
