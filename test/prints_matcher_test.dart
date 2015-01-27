// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library matcher.prints_matchers_test;

import 'dart:async';

import 'package:metatest/metatest.dart';
import 'package:unittest/unittest.dart';

/// The VM and dart2js have different toStrings for closures.
final closureToString = (() {}).toString();

void main() => initTests(_test);

void _test(message) {
  initMetatest(message);

  expectTestResults('synchronous', () {
    test("passes with an expected print", () {
      expect(() => print("Hello, world!"), prints("Hello, world!\n"));
    });

    test("combines multiple prints", () {
      expect(() {
        print("Hello");
        print("World!");
      }, prints("Hello\nWorld!\n"));
    });

    test("works with a Matcher", () {
      expect(() => print("Hello, world!"), prints(contains("Hello")));
    });

    test("describes a failure nicely", () {
      expect(() => print("Hello, world!"), prints("Goodbye, world!\n"));
    });

    test("describes a failure with a non-descriptive Matcher nicely", () {
      expect(() => print("Hello, world!"), prints(contains("Goodbye")));
    });

    test("describes a failure with no text nicely", () {
      expect(() {}, prints(contains("Goodbye")));
    });
  }, [
    {'result': 'pass'},
    {'result': 'pass'},
    {'result': 'pass'},
    {
      'result': 'fail',
      'message': r'''Expected: prints 'Goodbye, world!\n'
  ''
  Actual: <Closure: () => dynamic>
   Which: printed 'Hello, world!\n'
  ''
   Which: is different.
Expected: Goodbye, w ...
  Actual: Hello, wor ...
          ^
 Differ at offset 0
'''
    },
    {
      'result': 'fail',
      'message': r'''Expected: prints contains 'Goodbye'
  Actual: <Closure: () => dynamic>
   Which: printed 'Hello, world!\n'
  ''
'''
    },
    {
      'result': 'fail',
      'message': r'''Expected: prints contains 'Goodbye'
  Actual: <Closure: () => dynamic>
   Which: printed nothing.
'''
    }
  ]);

  expectTestResults('asynchronous', () {
    test("passes with an expected print", () {
      expect(() => new Future(() => print("Hello, world!")),
          prints("Hello, world!\n"));
    });

    test("combines multiple prints", () {
      expect(() => new Future(() {
        print("Hello");
        print("World!");
      }), prints("Hello\nWorld!\n"));
    });

    test("works with a Matcher", () {
      expect(() => new Future(() => print("Hello, world!")),
          prints(contains("Hello")));
    });

    test("describes a failure nicely", () {
      expect(() => new Future(() => print("Hello, world!")),
          prints("Goodbye, world!\n"));
    });

    test("describes a failure with a non-descriptive Matcher nicely", () {
      expect(() => new Future(() => print("Hello, world!")),
          prints(contains("Goodbye")));
    });

    test("describes a failure with no text nicely", () {
      expect(() => new Future.value(), prints(contains("Goodbye")));
    });
  }, [
    {'result': 'pass'},
    {'result': 'pass'},
    {'result': 'pass'},
    {
      'result': 'fail',
      'message': startsWith(r'''Expected future to complete successfully, but it failed with Expected: 'Goodbye, world!\n'
  ''
  Actual: 'Hello, world!\n'
  ''
   Which: is different.
Expected: Goodbye, w ...
  Actual: Hello, wor ...
          ^
 Differ at offset 0
''')
    },
    {
      'result': 'fail',
      'message': startsWith(r'''Expected future to complete successfully, but it failed with Expected: contains 'Goodbye'
  Actual: 'Hello, world!\n'
  ''
''')
    },
    {
      'result': 'fail',
      'message': startsWith(r'''Expected future to complete successfully, but it failed with Expected: contains 'Goodbye'
  Actual: ''
''')
    }
  ]);
}
