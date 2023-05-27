// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: only_throw_errors

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart' hide Result;
import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';
import 'package:test_api/hooks.dart';
import 'package:test_api/hooks_testing.dart';

import 'test_shared.dart';

void main() {
  group('Context', () {
    test('expectAsync holds test open', () async {
      late void Function() callback;
      final monitor = TestCaseMonitor.start(() {
        check(null).context.expectAsync(() => [''], (actual) async {
          final completer = Completer<void>();
          callback = completer.complete;
          await completer.future;
          return null;
        });
      });
      await pumpEventQueue();
      check(monitor).state.equals(State.running);
      callback();
      await monitor.onDone;
      check(monitor).didPass();
    });

    test('expectAsync does not hold test open past exception', () async {
      late void Function() callback;
      final monitor = TestCaseMonitor.start(() {
        check(null).context.expectAsync(() => [''], (actual) async {
          final completer = Completer<void>();
          callback = completer.complete;
          await completer.future;
          throw 'oh no!';
        });
      });
      await pumpEventQueue();
      check(monitor).state.equals(State.running);
      callback();
      await monitor.onDone;
      check(monitor)
        ..state.equals(State.failed)
        ..errors.single.has((e) => e.error, 'error').equals('oh no!');
    });

    test('nestAsync holds test open', () async {
      late void Function() callback;
      final monitor = TestCaseMonitor.start(() {
        check(null).context.nestAsync(() => [''], (actual) async {
          final completer = Completer<void>();
          callback = completer.complete;
          await completer.future;
          return Extracted.value(null);
        }, null);
      });
      await pumpEventQueue();
      check(monitor).state.equals(State.running);
      callback();
      await monitor.onDone;
      check(monitor).didPass();
    });

    test('nestAsync holds test open past async condition', () async {
      late void Function() callback;
      final monitor = TestCaseMonitor.start(() {
        check(null)
            .context
            .nestAsync(() => [''], (actual) async => Extracted.value(null),
                LazyCondition((it) async {
          final completer = Completer<void>();
          callback = completer.complete;
          await completer.future;
        }));
      });
      await pumpEventQueue();
      check(monitor).state.equals(State.running);
      callback();
      await monitor.onDone;
      check(monitor).didPass();
    });

    test('nestAsync does not hold test open past exception', () async {
      late void Function() callback;
      final monitor = TestCaseMonitor.start(() {
        check(null).context.nestAsync(() => [''], (actual) async {
          final completer = Completer<void>();
          callback = completer.complete;
          await completer.future;
          throw 'oh no!';
        }, null);
      });
      await pumpEventQueue();
      check(monitor).state.equals(State.running);
      callback();
      await monitor.onDone;
      check(monitor)
        ..state.equals(State.failed)
        ..errors.single.has((e) => e.error, 'error').equals('oh no!');
    });

    test('expectUnawaited can fail the test after it completes', () async {
      late void Function() callback;
      final monitor = await TestCaseMonitor.run(() {
        check(null).context.expectUnawaited(() => [''], (actual, reject) {
          final completer = Completer<void>()
            ..future.then((_) {
              reject(Rejection(which: ['foo']));
            });
          callback = completer.complete;
        });
      });
      check(monitor).state.equals(State.passed);
      callback();
      await pumpEventQueue();
      check(monitor)
        ..state.equals(State.failed)
        ..errors.unorderedMatches([
          it()
            ..has((e) => e.error, 'error')
                .isA<TestFailure>()
                .has((f) => f.message, 'message')
                .isNotNull()
                .endsWith('Which: foo'),
          it()
            ..has((e) => e.error, 'error')
                .isA<String>()
                .startsWith('This test failed after it had already completed.')
        ]);
    });
  });

  group('SkipExtension', () {
    test('marks the test as skipped', () async {
      final monitor = await TestCaseMonitor.run(() {
        check(null).skip('skip').isNotNull();
      });
      check(monitor).state.equals(State.skipped);
    });
  });
}

extension _MonitorChecks on Subject<TestCaseMonitor> {
  Subject<State> get state => has((m) => m.state, 'state');
  Subject<Iterable<AsyncError>> get errors => has((m) => m.errors, 'errors');
  Subject<StreamQueue<AsyncError>> get onError =>
      has((m) => m.onError, 'onError').withQueue;

  /// Expects that the monitored test is completed as success with no errors.
  ///
  /// Sets up an unawaited expectation that the test does not emit errors in the
  /// future in addition to checking there have been no errors yet.
  void didPass() {
    errors.isEmpty();
    state.equals(State.passed);
    onError.context.expectUnawaited(() => ['emits no further errors'],
        (actual, reject) async {
      await for (var error in actual.rest) {
        reject(Rejection(which: [
          ...prefixFirst('threw late error', literal(error.error)),
          ...const LineSplitter().convert(
              TestHandle.current.formatStackTrace(error.stackTrace).toString())
        ]));
      }
    });
  }
}
