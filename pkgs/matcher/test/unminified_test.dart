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

void main() {
  group('Iterable Matchers', () {
    test('isEmpty', () {
      var d = new SimpleIterable(0);
      var e = new SimpleIterable(1);
      shouldPass(d, isEmpty);
      shouldFail(e, isEmpty, "Expected: empty "
          "Actual: SimpleIterable:[1]");
    });

    test('isNotEmpty', () {
      var d = new SimpleIterable(0);
      var e = new SimpleIterable(1);
      shouldPass(e, isNotEmpty);
      shouldFail(d, isNotEmpty, "Expected: non-empty "
          "Actual: SimpleIterable:[]");
    });

    test('contains', () {
      var d = new SimpleIterable(3);
      shouldPass(d, contains(2));
      shouldFail(d, contains(5), "Expected: contains <5> "
          "Actual: SimpleIterable:[3, 2, 1]");
    });
  });

  group('Feature Matchers', () {
    test("Feature Matcher", () {
      var w = new Widget();
      w.price = 10;
      shouldPass(w, new HasPrice(10));
      shouldPass(w, new HasPrice(greaterThan(0)));
      shouldFail(w, new HasPrice(greaterThan(10)),
          "Expected: Widget with a price that is a value greater than <10> "
          "Actual: <Instance of 'Widget'> "
          "Which: has price with value <10> which is not "
          "a value greater than <10>");
    });
  });
}
