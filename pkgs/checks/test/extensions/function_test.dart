// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('ThrowsChecks', () {
    group('throws', () {
      test('succeeds for happy case', () {
        checkThat(() => throw StateError('oops!')).throws<StateError>();
      });
      test('fails for functions that return normally', () {
        checkThat(
          softCheck<void Function()>(() {}, it()..throws<StateError>()),
        ).isARejection(
            actual: ['a function that returned <null>'],
            which: ['did not throw']);
      });
      test('fails for functions that throw the wrong type', () {
        checkThat(
          softCheck<void Function()>(
            () => throw StateError('oops!'),
            it()..throws<ArgumentError>(),
          ),
        ).isARejection(
          actual: ['a function that threw error <Bad state: oops!>'],
          which: ['did not throw an ArgumentError'],
        );
      });
    });

    group('returnsNormally', () {
      test('succeeds for happy case', () {
        checkThat(() => 1).returnsNormally().equals(1);
      });
      test('fails for functions that throw', () {
        checkThat(softCheck<int Function()>(() {
          Error.throwWithStackTrace(
              StateError('oops!'), StackTrace.fromString('fake trace'));
        }, it()..returnsNormally()))
            .isARejection(
                actual: ['a function that throws'],
                which: ['threw <Bad state: oops!>', 'fake trace']);
      });
    });
  });
}
