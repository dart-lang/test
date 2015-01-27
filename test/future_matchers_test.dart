// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.future_matchers_test;

import 'dart:async';

import 'package:metatest/metatest.dart';
import 'package:unittest/unittest.dart';

void main() => initTests(_test);

void _test(message) {
  initMetatest(message);

  expectTestResults('group name test', () {
    test('completes - unexpected error', () {
      var completer = new Completer();
      completer.completeError('X');
      expect(completer.future, completes);
    });

    test('completes - successfully', () {
      var completer = new Completer();
      completer.complete('1');
      expect(completer.future, completes);
    });

    test('throws - unexpected to see normal completion', () {
      var completer = new Completer();
      completer.complete('1');
      expect(completer.future, throws);
    });

    test('throws - expected to see exception', () {
      var completer = new Completer();
      completer.completeError('X');
      expect(completer.future, throws);
    });

    test('throws - expected to see exception thrown later on', () {
      var completer = new Completer();
      var chained = completer.future.then((_) {
        throw 'X';
      });
      expect(chained, throws);
      completer.complete('1');
    });

    test('throwsA - unexpected normal completion', () {
      var completer = new Completer();
      completer.complete('1');
      expect(completer.future, throwsA(equals('X')));
    });

    test('throwsA - correct error', () {
      var completer = new Completer();
      completer.completeError('X');
      expect(completer.future, throwsA(equals('X')));
    });

    test('throwsA - wrong error', () {
      var completer = new Completer();
      completer.completeError('X');
      expect(completer.future, throwsA(equals('Y')));
    });
  }, [
    {
      'result': 'fail',
      'message': 'Expected future to complete successfully, but it failed with '
          'X',
    },
    {'result': 'pass'},
    {
      'result': 'fail',
      'message': 'Expected future to fail, but succeeded with \'1\'.'
    },
    {'result': 'pass'},
    {'result': 'pass'},
    {
      'result': 'fail',
      'message': 'Expected future to fail, but succeeded with \'1\'.'
    },
    {'result': 'pass'},
    {
      'result': 'fail',
      'message': '''Expected: 'Y'
  Actual: 'X'
   Which: is different.
Expected: Y
  Actual: X
          ^
 Differ at offset 0
'''
    }
  ]);
}
