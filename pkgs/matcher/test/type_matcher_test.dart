// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:matcher/matcher.dart';
import 'package:test/test.dart' show test, group;

import 'test_utils.dart';

void main() {
  _test('Map', isMap, {});
  _test('List', isList, []);
  _test('ArgumentError', isArgumentError, new ArgumentError());
  _test('Exception', isException, const FormatException());
  _test('FormatException', isFormatException, const FormatException());
  _test('StateError', isStateError, new StateError('oops'));
  _test('RangeError', isRangeError, new RangeError('oops'));
  _test('UnimplementedError', isUnimplementedError,
      new UnimplementedError('oops'));
  _test('UnsupportedError', isUnsupportedError, new UnsupportedError('oops'));
  _test('ConcurrentModificationError', isConcurrentModificationError,
      new ConcurrentModificationError());
  _test('CyclicInitializationError', isCyclicInitializationError,
      new CyclicInitializationError());
  _test('NoSuchMethodError', isNoSuchMethodError, null);
  _test('NullThrownError', isNullThrownError, new NullThrownError());

  group('custom `TypeMatcher`', () {
    _test('String', const isInstanceOf<String>(), 'hello');
    _test('String', const _StringMatcher(), 'hello');
  });
}

// TODO: drop `name` and use a type argument – once Dart2 semantics are enabled
void _test(String name, Matcher typeMatcher, Object matchingType) {
  group('for `$name`', () {
    if (matchingType != null) {
      test('succeeds', () {
        shouldPass(matchingType, typeMatcher);
      });
    }

    test('fails', () {
      shouldFail(
          const _TestType(),
          typeMatcher,
          anyOf(
              // Handles the TypeMatcher case
              equalsIgnoringWhitespace('Expected: $name Actual: ?:<TestType>'),
              // Handles the `isInstanceOf` case
              equalsIgnoringWhitespace(
                  'Expected: an instance of $name Actual: ?:<TestType>')));
    });
  });
}

class _StringMatcher extends TypeMatcher {
  const _StringMatcher() : super('String');

  bool matches(item, Map matchState) => item is String;
}

class _TestType {
  const _TestType();

  String toString() => 'TestType';
}
