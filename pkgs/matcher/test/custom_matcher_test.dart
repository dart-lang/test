// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:matcher/matcher.dart';
import 'package:test/test.dart' show test;

import 'test_utils.dart';

class _BadCustomMatcher extends CustomMatcher {
  _BadCustomMatcher() : super("feature", "description", {1: "a"});
  Object featureValueOf(actual) => throw new Exception("bang");
}

class _HasPrice extends CustomMatcher {
  _HasPrice(matcher) : super("Widget with a price that is", "price", matcher);
  Object featureValueOf(actual) => actual.price;
}

void main() {
  test("Feature Matcher", () {
    var w = new Widget();
    w.price = 10;
    shouldPass(w, new _HasPrice(10));
    shouldPass(w, new _HasPrice(greaterThan(0)));
    shouldFail(
        w,
        new _HasPrice(greaterThan(10)),
        "Expected: Widget with a price that is a value greater than <10> "
        "Actual: <Instance of 'Widget'> "
        "Which: has price with value <10> which is not "
        "a value greater than <10>");
  });

  test("Custom Matcher Exception", () {
    shouldFail(
        "a",
        new _BadCustomMatcher(),
        allOf([
          contains("Expected: feature {1: 'a'} "),
          contains("Actual: 'a' "),
          contains("Which: threw 'Exception: bang' "),
        ]));
  });
}
