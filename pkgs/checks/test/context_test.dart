// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
      check(monitor).hasState(State.running);
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
      check(monitor).hasState(State.running);
      callback();
      await monitor.onDone;
      check(monitor)
        ..hasState(State.failed)
        ..hasErrorsThat(it()
          ..hasSingleWhich(it()
            ..has((e) => e.error, 'error').which(it()..equals('oh no!'))));
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
      check(monitor).hasState(State.running);
      callback();
      await monitor.onDone;
      check(monitor).didPass();
    });

    test('nestAsync holds test open past async condition', () async {
      late void Function() callback;
      final monitor = TestCaseMonitor.start(() {
        check(null).context.nestAsync(() => [''], (actual) async {
          return Extracted.value(null);
        }, LazyCondition((it) async {
          final completer = Completer<void>();
          callback = completer.complete;
          await completer.future;
        }));
      });
      await pumpEventQueue();
      check(monitor).hasState(State.running);
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
      check(monitor).hasState(State.running);
      callback();
      await monitor.onDone;
      check(monitor)
        ..hasState(State.failed)
        ..hasErrorsThat(it()
          ..hasSingleWhich(it()
            ..has((e) => e.error, 'error').which(it()..equals('oh no!'))));
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
      check(monitor).hasState(State.passed);
      callback();
      await pumpEventQueue();
      check(monitor)
        ..hasState(State.failed)
        ..hasErrorsThat(it()
          ..unorderedMatches([
            it()
              ..isA<AsyncError>(it()
                ..has((e) => e.error, 'error').which(it()
                  ..isA<TestFailure>(it()
                    ..has((f) => f.message, 'message').which(
                        it()..isNotNull(it()..endsWith('Which: foo')))))),
            it()
              ..isA<AsyncError>(it()
                ..has((e) => e.error, 'error').which(it()
                  ..isA<String>(it()
                    ..startsWith(
                        'This test failed after it had already completed.'))))
          ]));
    });
  });

  group('SkipExtension', () {
    test('marks the test as skipped', () async {
      final monitor = await TestCaseMonitor.run(() {
        check(null).skip('skip').isNotNull();
      });
      check(monitor).hasState(State.skipped);
    });
  });
}

extension _MonitorChecks on Subject<TestCaseMonitor> {
  void hasState(State expectedState) =>
      has((m) => m.state, 'state').which(it()..equals(expectedState));
  void hasErrorsThat(Condition<Iterable<AsyncError>> errorCondition) =>
      has((m) => m.errors, 'errors').which(errorCondition);
  void hasOnErrorThat(Condition<StreamQueue<AsyncError>> onErrorCondition) =>
      has((m) => m.onError.withQueue, 'onError').which(onErrorCondition);

  /// Expects that the monitored test is completed as success with no errors.
  ///
  /// Sets up an unawaited expectation that the test does not emit errors in the
  /// future in addition to checking there have been no errors yet.
  void didPass() {
    hasErrorsThat(it()..isEmpty());
    hasState(State.passed);
    hasOnErrorThat(it()
      ..context.expectUnawaited(() => ['emits no further errors'],
          (actual, reject) async {
        await for (var error in actual.rest) {
          reject(Rejection(which: [
            ...prefixFirst('threw late error', literal(error.error)),
            ...(const LineSplitter().convert(TestHandle.current
                .formatStackTrace(error.stackTrace)
                .toString()))
          ]));
        }
      }));
  }
}
