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
    });

    group('prints', () {
      test('succeeds for happy case', () {
        check(() => print('Hello, world!')).prints().equals('Hello, world!\n');
      });

      test('combines multiple prints', () {
        check(() {
          print('Hello');
          print('world!');
        }).prints().equals('Hello\nworld!\n');
      });

      test('works with empty output', () {
        check(() {}).prints().isEmpty();
      });

      test('fails for functions that print different output', () {
        check(() => print('Hello, world!')).isRejectedBy(
          (it) => it.prints().equals('Goodbye, world!\n'),
          actual: ["'Hello, world!'"],
          which: [
            'differs at offset 0:',
            '  Goodbye, w ...',
            '  Hello, wor ...',
            '  ^',
          ],
        );
      });

      test('fails for functions that throw synchronously', () {
        check(() {
          Error.throwWithStackTrace(
            StateError('oops!'),
            StackTrace.fromString('fake trace'),
          );
        }).isRejectedBy(
          (it) => it.prints(),
          actual: ['a function that throws'],
          which: ['threw <Bad state: oops!> at:', '  fake trace'],
        );
      });

      test('fails for functions that return a Future', () {
        check(() async {}).isRejectedBy(
          (it) => it.prints(),
          actual: ['a function that returned a Future'],
          which: [
            'returned a Future; use printsAsync to test asynchronous functions',
          ],
        );
      });
    });

    group('printsAsync', () {
      test('succeeds for happy case', () async {
        await check(
          () => Future(() => print('Hello, world!')),
        ).printsAsync((it) => it.equals('Hello, world!\n'));
      });

      test('combines multiple prints in async functions', () async {
        await check(() async {
          print('Hello');
          await Future<void>.delayed(Duration.zero);
          print('world!');
        }).printsAsync((it) => it.equals('Hello\nworld!\n'));
      });

      test('works with synchronous functions', () async {
        await check(
          () => print('Hello, world!'),
        ).printsAsync((it) => it.equals('Hello, world!\n'));
      });

      test('works with empty output', () async {
        await check(() async {}).printsAsync((it) => it.isEmpty());
      });

      test('fails for async functions that print different output', () async {
        await check(
          () => Future(() => print('Hello, world!')),
        ).isRejectedByAsync(
          (it) => it.printsAsync((p) => p.equals('Goodbye, world!\n')),
          actual: ["'Hello, world!'"],
          which: [
            'differs at offset 0:',
            '  Goodbye, w ...',
            '  Hello, wor ...',
            '  ^',
          ],
        );
      });

      test('fails for async functions that complete with an error', () async {
        await check(() async {
          await Future<void>.delayed(Duration.zero);
          Error.throwWithStackTrace(
            StateError('oops!'),
            StackTrace.fromString('fake trace'),
          );
        }).isRejectedByAsync(
          (it) => it.printsAsync(),
          actual: ['a function that throws'],
          which: ['threw <Bad state: oops!> at:', '  fake trace'],
        );
      });

      test('fails for synchronous errors', () async {
        await check(() {
          Error.throwWithStackTrace(
            StateError('oops!'),
            StackTrace.fromString('fake trace'),
          );
        }).isRejectedByAsync(
          (it) => it.printsAsync(),
          actual: ['a function that throws'],
          which: ['threw <Bad state: oops!> at:', '  fake trace'],
        );
      });
    });
  });
}
