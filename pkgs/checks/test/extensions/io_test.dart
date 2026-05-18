// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:checks/io.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('IoFunctionChecks', () {
    group('exits', () {
      test('succeeds for happy case', () {
        check(() => exit(42)).exits().equals(42);
      });
      test('fails for functions that return normally', () {
        check(() {}).isRejectedBy(
          (it) => it.exits(),
          actual: ['a function that returned <null>'],
          which: ['did not exit'],
        );
      });
      test('fails for functions that throw', () {
        check(() {
          Error.throwWithStackTrace(
            StateError('oops!'),
            StackTrace.fromString('fake trace'),
          );
        }).isRejectedBy(
          (it) => it.exits(),
          actual: ['a function that threw error <Bad state: oops!>'],
          which: ['threw an exception at:', '  fake trace'],
        );
      });
      test('succeeds even if function catches Exception', () {
        check(() {
          try {
            exit(42);
          } on Exception catch (_) {
            // should not catch _ExitError
          }
        }).exits().equals(42);
      });
      test('fails if function catches Error', () {
        check(() {
          try {
            exit(42);
          } on Error catch (_) {
            // swallows _ExitError
          }
        }).isRejectedBy(
          (it) => it.exits(),
          actual: ['a function that returned <null>'],
          which: ['did not exit'],
        );
      });
    });
  });

  group('IoAsyncFunctionChecks', () {
    group('exits', () {
      test('succeeds for happy case', () async {
        await check(() async => exit(42)).exits((it) => it.equals(42));
      });
      test('succeeds for synchronous exit', () async {
        Future<void> syncExit() {
          exit(42);
        }

        await check(syncExit).exits((it) => it.equals(42));
      });
      test('fails for futures that complete normally', () async {
        await check(() async => 1).isRejectedByAsync(
          (it) => it.exits(),
          actual: ['completed to <1>'],
          which: ['did not exit'],
        );
      });
      test('fails for futures that complete to an error', () async {
        await check(_futureFail).isRejectedByAsync(
          (it) => it.exits(),
          actual: ['completed to error <UnimplementedError>'],
          which: ['threw an exception at:', '  fake trace'],
        );
      });
      test('can be described', () async {
        await check(
          (Subject<Future<void> Function()> it) => it.exits(),
        ).hasAsyncDescriptionWhich(
          (it) => it.deepEquals(['  exits the process']),
        );
        await check(
          (Subject<Future<void> Function()> it) =>
              it.exits((it) => it.equals(42)),
        ).hasAsyncDescriptionWhich(
          (it) =>
              it.deepEquals(['  exits the process that:', '    equals <42>']),
        );
      });
    });
  });
}

Future<int> _futureFail() =>
    Future.error(UnimplementedError(), StackTrace.fromString('fake trace'));
