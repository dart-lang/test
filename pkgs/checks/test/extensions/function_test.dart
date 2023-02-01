// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('ThrowsChecks', () {
    group('throws', () {
      test('succeeds for happy case', () {
        (() => throw StateError('oops!')).must.throwException<StateError>();
      });
      test('fails for functions that return normally', () {
        (() {}).must.beRejectedBy(would()..throwException<StateError>(),
            actual: ['a function that returned <null>'],
            which: ['did not throw']);
      });
      test('fails for functions that throw the wrong type', () {
        (() => throw StateError('oops!')).must.beRejectedBy(
          would()..throwException<ArgumentError>(),
          actual: ['a function that threw error <Bad state: oops!>'],
          which: ['did not throw an ArgumentError'],
        );
      });
    });

    group('returnsNormally', () {
      test('succeeds for happy case', () {
        (() => 1).must.returnNormally().equal(1);
      });
      test('fails for functions that throw', () {
        (() {
          Error.throwWithStackTrace(
              StateError('oops!'), StackTrace.fromString('fake trace'));
        }).must.beRejectedBy(would()..returnNormally(),
            actual: ['a function that throws'],
            which: ['threw <Bad state: oops!>', 'fake trace']);
      });
    });
  });
}
