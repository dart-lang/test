// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:spectate/spectate.dart';
import 'package:test/test.dart';

void main() {
  group('CallCounter synchronous extensions', () {
    test('arity 0', () {
      var executed = 0;
      void fn() {
        executed++;
      }

      final (counter, callback) = fn.countCalls;
      check(counter.callCount).equals(0);
      check(counter.called).isFalse;

      callback();
      check(counter.callCount).equals(1);
      check(counter.called).isTrue;
      check(executed).equals(1);

      callback();
      check(counter.callCount).equals(2);
      check(executed).equals(2);
    });

    test('arity 1', () {
      final received = <String>[];
      void fn(String a) {
        received.add(a);
      }

      final (counter, callback) = fn.countCalls;
      callback('first');
      callback('second');
      check(counter.callCount).equals(2);
      check(received).deepEquals(['first', 'second']);
    });

    test('arity 2', () {
      final received = <(int, String)>[];
      void fn(int a, String b) {
        received.add((a, b));
      }

      final (counter, callback) = fn.countCalls;
      callback(1, 'a');
      check(counter.callCount).equals(1);
      check(received).deepEquals([(1, 'a')]);
    });

    test('arity 3', () {
      final received = <(int, String, bool)>[];
      void fn(int a, String b, bool c) {
        received.add((a, b, c));
      }

      final (counter, callback) = fn.countCalls;
      callback(1, 'a', true);
      check(counter.callCount).equals(1);
      check(received).deepEquals([(1, 'a', true)]);
    });

    test('arity 4', () {
      final received = <(int, String, bool, double)>[];
      void fn(int a, String b, bool c, double d) {
        received.add((a, b, c, d));
      }

      final (counter, callback) = fn.countCalls;
      callback(1, 'a', true, 3.14);
      check(counter.callCount).equals(1);
      check(received).deepEquals([(1, 'a', true, 3.14)]);
    });

    test('arity 5', () {
      final received = <(int, String, bool, double, String)>[];
      void fn(int a, String b, bool c, double d, String e) {
        received.add((a, b, c, d, e));
      }

      final (counter, callback) = fn.countCalls;
      callback(1, 'a', true, 3.14, 'item');
      check(counter.callCount).equals(1);
      check(received).deepEquals([(1, 'a', true, 3.14, 'item')]);
    });
  });

  group('CallCounter asynchronous extensions', () {
    test('arity 0', () async {
      var executed = 0;
      Future<void> fn() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        executed++;
      }

      final (counter, callback) = fn.countCalls;
      check(counter.callCount).equals(0);

      await callback();
      check(counter.callCount).equals(1);
      check(executed).equals(1);

      await callback();
      check(counter.callCount).equals(2);
      check(executed).equals(2);
    });

    test('arity 1', () async {
      final received = <String>[];
      Future<void> fn(String a) async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        received.add(a);
      }

      final (counter, callback) = fn.countCalls;
      await callback('async one');
      check(counter.callCount).equals(1);
      check(received).deepEquals(['async one']);
    });

    test('arity 2', () async {
      final received = <(int, String)>[];
      Future<void> fn(int a, String b) async {
        received.add((a, b));
      }

      final (counter, callback) = fn.countCalls;
      await callback(1, 'b');
      check(counter.callCount).equals(1);
      check(received).deepEquals([(1, 'b')]);
    });

    test('arity 3', () async {
      final received = <(int, String, bool)>[];
      Future<void> fn(int a, String b, bool c) async {
        received.add((a, b, c));
      }

      final (counter, callback) = fn.countCalls;
      await callback(1, 'b', false);
      check(counter.callCount).equals(1);
      check(received).deepEquals([(1, 'b', false)]);
    });

    test('arity 4', () async {
      final received = <(int, String, bool, double)>[];
      Future<void> fn(int a, String b, bool c, double d) async {
        received.add((a, b, c, d));
      }

      final (counter, callback) = fn.countCalls;
      await callback(1, 'b', false, 1.2);
      check(counter.callCount).equals(1);
      check(received).deepEquals([(1, 'b', false, 1.2)]);
    });

    test('arity 5', () async {
      final received = <(int, String, bool, double, String)>[];
      Future<void> fn(int a, String b, bool c, double d, String e) async {
        received.add((a, b, c, d, e));
      }

      final (counter, callback) = fn.countCalls;
      await callback(1, 'b', false, 1.2, 'z');
      check(counter.callCount).equals(1);
      check(received).deepEquals([(1, 'b', false, 1.2, 'z')]);
    });
  });
}
