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
        check(() => throw StateError('oops!')).throws<StateError>();
      });
      test('fails for functions that return normally', () {
        check(() {}).isRejectedBy(
          (it) => it.throws<StateError>(),
          actual: ['a function that returned <null>'],
          which: ['did not throw'],
        );
      });
      test('fails for functions that throw the wrong type', () {
        check(() {
          Error.throwWithStackTrace(
            StateError('oops!'),
            StackTrace.fromString('fake trace'),
          );
        }).isRejectedBy(
          (it) => it.throws<ArgumentError>(),
          actual: ['a function that threw error <Bad state: oops!>'],
          which: [
            'threw an exception that is not a ArgumentError at:',
            '  fake trace',
          ],
        );
      });
      test('evaluates condition', () {
        check(() => throw StateError('oops!')).isRejectedBy(
          (it) => it.throws<StateError>(
            (it) => it.has((e) => e.message, 'message').equals('wrong'),
          ),
          actual: ["'oops!'"],
          which: ['differs at offset 0:', '  wrong', '  oops!', '  ^'],
        );
      });
      test('returns valid subject', () {
        check(
          () => throw StateError('oops!'),
        ).throws<StateError>().has((e) => e.message, 'message').equals('oops!');
      });
    });

    group('returnsNormally', () {
      test('succeeds for happy case', () {
        check(() => 1).returnsNormally().equals(1);
      });
      test('fails for functions that throw', () {
        check(() {
          Error.throwWithStackTrace(
            StateError('oops!'),
            StackTrace.fromString('fake trace'),
          );
        }).isRejectedBy(
          (it) => it.returnsNormally(),
          actual: ['a function that throws'],
          which: ['threw <Bad state: oops!> at:', '  fake trace'],
        );
      });
      test('evaluates condition', () {
        check(() => 1).isRejectedBy(
          (it) => it.returnsNormally((it) => it.equals(2)),
          actual: ['<1>'],
          which: ['are not equal'],
        );
      });
      test('returns valid subject', () {
        check(() => 1).returnsNormally().equals(1);
      });
    });
  });
}
