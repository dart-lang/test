// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:spectate/spectate.dart';
import 'package:test/test.dart';

void main() {
  group('PrintSpy.spectate', () {
    test('captures prints from synchronous callback', () {
      final prints = PrintSpy.spectate(() {
        print('hello');
        print('world');
      });
      check(prints).deepEquals(['hello', 'world']);
    });

    test('returns empty iterable when nothing is printed', () {
      final prints = PrintSpy.spectate(() {});
      check(prints).isEmpty;
    });

    test('rethrows exception thrown by callback', () {
      check(() {
        PrintSpy.spectate(() {
          print('before error');
          throw StateError('failure');
        });
      }).throws<StateError>();
    });
  });

  group('PrintSpy.spectateAsync', () {
    test('emits prints from asynchronous callback', () async {
      final stream = PrintSpy.spectateAsync(() async {
        print('first');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        print('second');
      });
      check(await stream.toList()).deepEquals(['first', 'second']);
    });

    test('emits error if callback throws asynchronously', () async {
      final stream = PrintSpy.spectateAsync(() async {
        print('before error');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        throw StateError('async failure');
      });
      final queue = check(stream).withQueue;
      await queue.emits(Condition.it()..equals('before error'));
      await queue.emitsError<StateError>();
    });
  });

  group('PrintSpy synchronous extensions', () {
    test('arity 0', () {
      void fn() {
        print('call 0');
      }

      final (spy, callback) = fn.spectatePrint;
      check(spy.callCount).equals(0);
      check(spy.prints).isEmpty;
      check(spy.calls).isEmpty;

      callback();
      check(spy.callCount).equals(1);
      check(spy.prints).deepEquals(['call 0']);
      check(spy.calls).deepEquals([
        ['call 0'],
      ]);

      callback();
      check(spy.callCount).equals(2);
      check(spy.prints).deepEquals(['call 0', 'call 0']);
      check(spy.calls).deepEquals([
        ['call 0'],
        ['call 0'],
      ]);
    });

    test('arity 1', () {
      void fn(String a) {
        print('arg: $a');
      }

      final (spy, callback) = fn.spectatePrint;
      callback('one');
      callback('two');
      check(spy.callCount).equals(2);
      check(spy.prints).deepEquals(['arg: one', 'arg: two']);
      check(spy.calls).deepEquals([
        ['arg: one'],
        ['arg: two'],
      ]);
    });

    test('arity 2', () {
      void fn(String a, int b) {
        print('$a:$b');
      }

      final (spy, callback) = fn.spectatePrint;
      callback('val', 42);
      check(spy.prints).deepEquals(['val:42']);
    });

    test('arity 3', () {
      void fn(String a, int b, bool c) {
        print('$a:$b:$c');
      }

      final (spy, callback) = fn.spectatePrint;
      callback('val', 42, true);
      check(spy.prints).deepEquals(['val:42:true']);
    });

    test('arity 4', () {
      void fn(String a, int b, bool c, double d) {
        print('$a:$b:$c:$d');
      }

      final (spy, callback) = fn.spectatePrint;
      callback('val', 42, true, 3.14);
      check(spy.prints).deepEquals(['val:42:true:3.14']);
    });

    test('arity 5', () {
      void fn(String a, int b, bool c, double d, List<int> e) {
        print('$a:$b:$c:$d:$e');
      }

      final (spy, callback) = fn.spectatePrint;
      callback('val', 42, true, 3.14, [1]);
      check(spy.prints).deepEquals(['val:42:true:3.14:[1]']);
    });
  });

  group('PrintSpy asynchronous extensions', () {
    test('arity 0', () async {
      Future<void> fn() async {
        print('async 0');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        print('async 0 done');
      }

      final (spy, callback) = fn.spectatePrint;
      await callback();
      check(spy.callCount).equals(1);
      check(spy.prints).deepEquals(['async 0', 'async 0 done']);
      check(spy.calls).deepEquals([
        ['async 0', 'async 0 done'],
      ]);
    });

    test('arity 1', () async {
      Future<void> fn(String a) async {
        print('async $a');
      }

      final (spy, callback) = fn.spectatePrint;
      await callback('hello');
      check(spy.prints).deepEquals(['async hello']);
    });

    test('arity 2', () async {
      Future<void> fn(String a, int b) async {
        print('async $a:$b');
      }

      final (spy, callback) = fn.spectatePrint;
      await callback('num', 7);
      check(spy.prints).deepEquals(['async num:7']);
    });

    test('arity 3', () async {
      Future<void> fn(String a, int b, bool c) async {
        print('async $a:$b:$c');
      }

      final (spy, callback) = fn.spectatePrint;
      await callback('val', 1, false);
      check(spy.prints).deepEquals(['async val:1:false']);
    });

    test('arity 4', () async {
      Future<void> fn(String a, int b, bool c, double d) async {
        print('async $a:$b:$c:$d');
      }

      final (spy, callback) = fn.spectatePrint;
      await callback('val', 1, false, 2.5);
      check(spy.prints).deepEquals(['async val:1:false:2.5']);
    });

    test('arity 5', () async {
      Future<void> fn(String a, int b, bool c, double d, String e) async {
        print('async $a:$b:$c:$d:$e');
      }

      final (spy, callback) = fn.spectatePrint;
      await callback('a', 1, true, 2.5, 'e');
      check(spy.prints).deepEquals(['async a:1:true:2.5:e']);
    });
  });
}
