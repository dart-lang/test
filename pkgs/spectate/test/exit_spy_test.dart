// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:spectate/io.dart';
import 'package:test/test.dart';

void main() {
  group('ExitSpy.spectate', () {
    test('captures exit code when exit() is called', () {
      final code = ExitSpy.spectate(() {
        exit(42);
      });
      check(code).equals(42);
    });

    test('returns null when exit() is not called', () {
      final code = ExitSpy.spectate(() {});
      check(code).isNull;
    });

    test('rethrows non-exit exceptions', () {
      check(() {
        ExitSpy.spectate(() {
          throw const FormatException('invalid format');
        });
      }).throws<FormatException>();
    });
  });

  group('ExitSpy.spectateAsync', () {
    test(
      'captures exit code when exit() is called in async callback',
      () async {
        final code = await ExitSpy.spectateAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          exit(1);
        });
        check(code).equals(1);
      },
    );

    test('returns null when exit() is not called', () async {
      final code = await ExitSpy.spectateAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      check(code).isNull;
    });

    test('rethrows non-exit exceptions asynchronously', () async {
      await check(
        ExitSpy.spectateAsync(() async {
          throw const FormatException('invalid format');
        }),
      ).throws<FormatException>();
    });
  });

  group('ExitSpy synchronous extensions', () {
    test('arity 0', () {
      var executedAfterExit = false;
      void fn() {
        if (!executedAfterExit) exit(0);
        executedAfterExit = true;
      }

      final (spy, callback) = fn.spectateExit;
      check(spy.exited).isFalse;
      check(spy.exitCode).isNull;
      check(spy.exitCodes).isEmpty;
      check(spy.callCount).equals(0);

      callback();
      check(spy.exited).isTrue;
      check(spy.exitCode).equals(0);
      check(spy.exitCodes).deepEquals([0]);
      check(spy.callCount).equals(1);
      check(executedAfterExit).isFalse;
    });

    test('arity 1', () {
      void fn(int code) {
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      callback(123);
      check(spy.exitCode).equals(123);
      check(spy.exitCodes).deepEquals([123]);
    });

    test('arity 2', () {
      void fn(String _, int code) {
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      callback('ign', 2);
      check(spy.exitCode).equals(2);
    });

    test('arity 3', () {
      void fn(String _, bool _, int code) {
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      callback('ign', true, 3);
      check(spy.exitCode).equals(3);
    });

    test('arity 4', () {
      void fn(String _, bool _, double _, int code) {
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      callback('ign', true, 3.14, 4);
      check(spy.exitCode).equals(4);
    });

    test('arity 5', () {
      void fn(String _, bool _, double _, List<int> _, int code) {
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      callback('ign', true, 3.14, const [], 5);
      check(spy.exitCode).equals(5);
    });

    test('does not catch non-exit exceptions', () {
      void fn() {
        throw StateError('unhandled');
      }

      final (_, callback) = fn.spectateExit;
      check(callback).throws<StateError>();
    });
  });

  group('ExitSpy asynchronous extensions', () {
    test('arity 0', () async {
      var executedAfterExit = false;
      Future<void> fn() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        if (!executedAfterExit) exit(10);
        executedAfterExit = true;
      }

      final (spy, callback) = fn.spectateExit;
      await callback();
      check(spy.exited).isTrue;
      check(spy.exitCode).equals(10);
      check(executedAfterExit).isFalse;
    });

    test('arity 1', () async {
      Future<void> fn(int code) async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      await callback(11);
      check(spy.exitCode).equals(11);
    });

    test('arity 2', () async {
      Future<void> fn(String _, int code) async {
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      await callback('ign', 12);
      check(spy.exitCode).equals(12);
    });

    test('arity 3', () async {
      Future<void> fn(String _, bool _, int code) async {
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      await callback('ign', false, 13);
      check(spy.exitCode).equals(13);
    });

    test('arity 4', () async {
      Future<void> fn(String _, bool _, double _, int code) async {
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      await callback('ign', false, 1.0, 14);
      check(spy.exitCode).equals(14);
    });

    test('arity 5', () async {
      Future<void> fn(String _, bool _, double _, String _, int code) async {
        exit(code);
      }

      final (spy, callback) = fn.spectateExit;
      await callback('ign', false, 1.0, 'a', 15);
      check(spy.exitCode).equals(15);
    });

    test('does not catch non-exit exceptions', () async {
      Future<void> fn() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        throw StateError('unhandled async');
      }

      final (_, callback) = fn.spectateExit;
      await check(callback()).throws<StateError>();
    });
  });
}
