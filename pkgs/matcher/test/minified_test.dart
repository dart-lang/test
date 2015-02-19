// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This file is for matcher tests that rely on the names of various Dart types.
// These tests will fail when run in minified dart2js, since the names will be
// mangled. A version of this file that works in minified dart2js is in
// matchers_minified_test.dart.

import 'package:matcher/matcher.dart';
import 'package:unittest/unittest.dart';

import 'test_utils.dart';

// A regexp fragment matching a minified name.
const _MINIFIED_NAME = r"[A-Za-z0-9]{1,3}";

void main() {
  group('Iterable Matchers', () {
    test('isEmpty', () {
      var d = new SimpleIterable(0);
      var e = new SimpleIterable(1);
      shouldPass(d, isEmpty);
      shouldFail(e, isEmpty,
          matches(r"Expected: empty +Actual: " + _MINIFIED_NAME + r":\[1\]"));
    });

    test('isNotEmpty', () {
      var d = new SimpleIterable(0);
      var e = new SimpleIterable(1);
      shouldPass(e, isNotEmpty);
      shouldFail(d, isNotEmpty, matches(
          r"Expected: non-empty +Actual: " + _MINIFIED_NAME + r":\[\]"));
    });

    test('contains', () {
      var d = new SimpleIterable(3);
      shouldPass(d, contains(2));
      shouldFail(d, contains(5), matches(r"Expected: contains <5> +"
          r"Actual: " + _MINIFIED_NAME + r":\[3, 2, 1\]"));
    });
  });

  group('Feature Matchers', () {
    test("Feature Matcher", () {
      var w = new Widget();
      w.price = 10;
      shouldPass(w, new HasPrice(10));
      shouldPass(w, new HasPrice(greaterThan(0)));
      shouldFail(w, new HasPrice(greaterThan(10)), matches(
          r"Expected: Widget with a price that is a value greater than "
              r"<10> +"
              r"Actual: <Instance of '" + _MINIFIED_NAME + r"'> +"
              r"Which: has price with value <10> which is not "
              r"a value greater than <10>"));
    });
  });
}
