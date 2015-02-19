// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library matcher.test_utils;

import 'dart:collection';

import 'package:unittest/unittest.dart';

void shouldFail(value, Matcher matcher, expected) {
  var failed = false;
  try {
    expect(value, matcher);
  } on TestFailure catch (err) {
    failed = true;

    var _errorString = err.message;

    if (expected is String) {
      expect(_errorString, equalsIgnoringWhitespace(expected));
    } else {
      expect(_errorString.replaceAll('\n', ''), expected);
    }
  }

  expect(failed, isTrue, reason: 'Expected to fail.');
}

void shouldPass(value, Matcher matcher) {
  expect(value, matcher);
}

doesNotThrow() {}
doesThrow() {
  throw 'X';
}

class Widget {
  int price;
}

class HasPrice extends CustomMatcher {
  HasPrice(matcher) : super("Widget with a price that is", "price", matcher);
  featureValueOf(actual) => actual.price;
}

class SimpleIterable extends IterableBase<int> {
  final int count;

  SimpleIterable(this.count);

  bool contains(int val) => count < val ? false : true;

  bool any(bool f(element)) {
    for (var i = 0; i <= count; i++) {
      if (f(i)) return true;
    }
    return false;
  }

  String toString() => "<[$count]>";

  Iterator get iterator {
    return new _SimpleIterator(count);
  }
}

class _SimpleIterator implements Iterator<int> {
  int _count;
  int _current;

  _SimpleIterator(this._count);

  bool moveNext() {
    if (_count > 0) {
      _current = _count;
      _count--;
      return true;
    }
    _current = null;
    return false;
  }

  int get current => _current;
}
