// Copyright 2014 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';

import 'package:test/test.dart';

main() {
  var initialTime = new DateTime(2000);
  var elapseBy = new Duration(days: 1);

  test('should set initial time', () {
    expect(new FakeAsync().getClock(initialTime).now(), initialTime);
  });

  group('elapseBlocking', () {
    test('should elapse time without calling timers', () {
      new Timer(elapseBy ~/ 2, neverCalledVoid);
      new FakeAsync().elapseBlocking(elapseBy);
    });

    test('should elapse time by the specified amount', () {
      var async = new FakeAsync();
      async.elapseBlocking(elapseBy);
      expect(async.elapsed, elapseBy);
    });

    test('should throw when called with a negative duration', () {
      expect(() => new FakeAsync().elapseBlocking(new Duration(days: -1)),
          throwsArgumentError);
    });
  });

  group('elapse', () {
    test('should elapse time by the specified amount', () {
      new FakeAsync().run((async) {
        async.elapse(elapseBy);
        expect(async.elapsed, elapseBy);
      });
    });

    test('should throw ArgumentError when called with a negative duration', () {
      expect(() => new FakeAsync().elapse(new Duration(days: -1)),
          throwsArgumentError);
    });

    test('should throw when called before previous call is complete', () {
      new FakeAsync().run((async) {
        new Timer(elapseBy ~/ 2, expectAsync0(() {
          expect(() => async.elapse(elapseBy), throwsStateError);
        }));
        async.elapse(elapseBy);
      });
    });

    group('when creating timers', () {
      test('should call timers expiring before or at end time', () {
        new FakeAsync().run((async) {
          new Timer(elapseBy ~/ 2, expectAsync0(() {}));
          new Timer(elapseBy, expectAsync0(() {}));
          async.elapse(elapseBy);
        });
      });

      test('should call timers expiring due to elapseBlocking', () {
        new FakeAsync().run((async) {
          new Timer(elapseBy, () => async.elapseBlocking(elapseBy));
          new Timer(elapseBy * 2, expectAsync0(() {}));
          async.elapse(elapseBy);
          expect(async.elapsed, elapseBy * 2);
        });
      });

      test('should call timers at their scheduled time', () {
        new FakeAsync().run((async) {
          new Timer(elapseBy ~/ 2, expectAsync0(() {
            expect(async.elapsed, elapseBy ~/ 2);
          }));

          var periodicCalledAt = <Duration>[];
          new Timer.periodic(
              elapseBy ~/ 2, (_) => periodicCalledAt.add(async.elapsed));

          async.elapse(elapseBy);
          expect(periodicCalledAt, [elapseBy ~/ 2, elapseBy]);
        });
      });

      test('should not call timers expiring after end time', () {
        new FakeAsync().run((async) {
          new Timer(elapseBy * 2, neverCalledVoid);
          async.elapse(elapseBy);
        });
      });

      test('should not call canceled timers', () {
        new FakeAsync().run((async) {
          var timer = new Timer(elapseBy ~/ 2, neverCalledVoid);
          timer.cancel();
          async.elapse(elapseBy);
        });
      });

      test('should call periodic timers each time the duration elapses', () {
        new FakeAsync().run((async) {
          new Timer.periodic(elapseBy ~/ 10, expectAsync1((_) {}, count: 10));
          async.elapse(elapseBy);
        });
      });

      test('should call timers occurring at the same time in FIFO order', () {
        new FakeAsync().run((async) {
          var log = [];
          new Timer(elapseBy ~/ 2, () => log.add('1'));
          new Timer(elapseBy ~/ 2, () => log.add('2'));
          async.elapse(elapseBy);
          expect(log, ['1', '2']);
        });
      });

      test('should maintain FIFO order even with periodic timers', () {
        new FakeAsync().run((async) {
          var log = [];
          new Timer.periodic(elapseBy ~/ 2, (_) => log.add('periodic 1'));
          new Timer(elapseBy ~/ 2, () => log.add('delayed 1'));
          new Timer(elapseBy, () => log.add('delayed 2'));
          new Timer.periodic(elapseBy, (_) => log.add('periodic 2'));

          async.elapse(elapseBy);
          expect(log, [
            'periodic 1',
            'delayed 1',
            'periodic 1',
            'delayed 2',
            'periodic 2'
          ]);
        });
      });

      test('should process microtasks surrounding each timer', () {
        new FakeAsync().run((async) {
          var microtaskCalls = 0;
          var timerCalls = 0;
          scheduleMicrotasks() {
            for (var i = 0; i < 5; i++) {
              scheduleMicrotask(() => microtaskCalls++);
            }
          }

          scheduleMicrotasks();
          new Timer.periodic(elapseBy ~/ 5, (_) {
            timerCalls++;
            expect(microtaskCalls, 5 * timerCalls);
            scheduleMicrotasks();
          });
          async.elapse(elapseBy);
          expect(timerCalls, 5);
          expect(microtaskCalls, 5 * (timerCalls + 1));
        });
      });

      test('should pass the periodic timer itself to callbacks', () {
        new FakeAsync().run((async) {
          Timer constructed;
          constructed = new Timer.periodic(elapseBy, expectAsync1((passed) {
            expect(passed, same(constructed));
          }));
          async.elapse(elapseBy);
        });
      });

      test('should call microtasks before advancing time', () {
        new FakeAsync().run((async) {
          scheduleMicrotask(expectAsync0(() {
            expect(async.elapsed, Duration.zero);
          }));
          async.elapse(new Duration(minutes: 1));
        });
      });

      test('should add event before advancing time', () {
        new FakeAsync().run((async) {
          var controller = new StreamController();
          expect(controller.stream.first.then((_) {
            expect(async.elapsed, Duration.zero);
          }), completes);
          controller.add(null);
          async.elapse(new Duration(minutes: 1));
        });
      });

      test('should increase negative duration timers to zero duration', () {
        new FakeAsync().run((async) {
          var negativeDuration = new Duration(days: -1);
          new Timer(negativeDuration, expectAsync0(() {
            expect(async.elapsed, Duration.zero);
          }));
          async.elapse(new Duration(minutes: 1));
        });
      });

      test('should not be additive with elapseBlocking', () {
        new FakeAsync().run((async) {
          new Timer(Duration.zero, () => async.elapseBlocking(elapseBy * 5));
          async.elapse(elapseBy);
          expect(async.elapsed, elapseBy * 5);
        });
      });

      group('isActive', () {
        test('should be false after timer is run', () {
          new FakeAsync().run((async) {
            var timer = new Timer(elapseBy ~/ 2, () {});
            async.elapse(elapseBy);
            expect(timer.isActive, isFalse);
          });
        });

        test('should be true after periodic timer is run', () {
          new FakeAsync().run((async) {
            var timer = new Timer.periodic(elapseBy ~/ 2, (_) {});
            async.elapse(elapseBy);
            expect(timer.isActive, isTrue);
          });
        });

        test('should be false after timer is canceled', () {
          new FakeAsync().run((async) {
            var timer = new Timer(elapseBy ~/ 2, () {});
            timer.cancel();
            expect(timer.isActive, isFalse);
          });
        });
      });

      test('should work with new Future()', () {
        new FakeAsync().run((async) {
          new Future(expectAsync0(() {}));
          async.elapse(Duration.zero);
        });
      });

      test('should work with Future.delayed', () {
        new FakeAsync().run((async) {
          new Future.delayed(elapseBy, expectAsync0(() {}));
          async.elapse(elapseBy);
        });
      });

      test('should work with Future.timeout', () {
        new FakeAsync().run((async) {
          var completer = new Completer();
          expect(completer.future.timeout(elapseBy ~/ 2),
              throwsA(new TypeMatcher<TimeoutException>()));
          async.elapse(elapseBy);
          completer.complete();
        });
      });

      // TODO: Pausing and resuming the timeout Stream doesn't work since
      // it uses `new Stopwatch()`.
      //
      // See https://code.google.com/p/dart/issues/detail?id=18149
      test('should work with Stream.periodic', () {
        new FakeAsync().run((async) {
          expect(new Stream.periodic(new Duration(minutes: 1), (i) => i),
              emitsInOrder([0, 1, 2]));
          async.elapse(new Duration(minutes: 3));
        });
      });

      test('should work with Stream.timeout', () {
        new FakeAsync().run((async) {
          var controller = new StreamController<int>();
          var timed = controller.stream.timeout(new Duration(minutes: 2));

          var events = <int>[];
          var errors = [];
          timed.listen(events.add, onError: errors.add);

          controller.add(0);
          async.elapse(new Duration(minutes: 1));
          expect(events, [0]);

          async.elapse(new Duration(minutes: 1));
          expect(errors, hasLength(1));
          expect(errors.first, new TypeMatcher<TimeoutException>());
        });
      });
    });
  });

  group('flushMicrotasks', () {
    test('should flush a microtask', () {
      new FakeAsync().run((async) {
        new Future.microtask(expectAsync0(() {}));
        async.flushMicrotasks();
      });
    });

    test('should flush microtasks scheduled by microtasks in order', () {
      new FakeAsync().run((async) {
        var log = [];
        scheduleMicrotask(() {
          log.add(1);
          scheduleMicrotask(() => log.add(3));
        });
        scheduleMicrotask(() => log.add(2));

        async.flushMicrotasks();
        expect(log, [1, 2, 3]);
      });
    });

    test('should not run timers', () {
      new FakeAsync().run((async) {
        var log = [];
        scheduleMicrotask(() => log.add(1));
        Timer.run(() => log.add(2));
        new Timer.periodic(new Duration(seconds: 1), (_) => log.add(2));

        async.flushMicrotasks();
        expect(log, [1]);
      });
    });
  });

  group('flushTimers', () {
    test('should flush timers in FIFO order', () {
      new FakeAsync().run((async) {
        var log = [];
        Timer.run(() {
          log.add(1);
          new Timer(elapseBy, () => log.add(3));
        });
        Timer.run(() => log.add(2));

        async.flushTimers(timeout: elapseBy * 2);
        expect(log, [1, 2, 3]);
        expect(async.elapsed, elapseBy);
      });
    });

    test(
        'should run collateral periodic timers with non-periodic first if '
        'scheduled first', () {
      new FakeAsync().run((async) {
        var log = [];
        new Timer(new Duration(seconds: 2), () => log.add('delayed'));
        new Timer.periodic(
            new Duration(seconds: 1), (_) => log.add('periodic'));

        async.flushTimers(flushPeriodicTimers: false);
        expect(log, ['periodic', 'delayed', 'periodic']);
      });
    });

    test(
        'should run collateral periodic timers with periodic first '
        'if scheduled first', () {
      new FakeAsync().run((async) {
        var log = [];
        new Timer.periodic(
            new Duration(seconds: 1), (_) => log.add('periodic'));
        new Timer(new Duration(seconds: 2), () => log.add('delayed'));

        async.flushTimers(flushPeriodicTimers: false);
        expect(log, ['periodic', 'periodic', 'delayed']);
      });
    });

    test('should time out', () {
      new FakeAsync().run((async) {
        // Schedule 3 timers. All but the last one should fire.
        for (var delay in [30, 60, 90]) {
          new Timer(new Duration(minutes: delay),
              expectAsync0(() {}, count: delay == 90 ? 0 : 1));
        }

        expect(() => async.flushTimers(), throwsStateError);
      });
    });

    test('should time out a chain of timers', () {
      new FakeAsync().run((async) {
        var count = 0;
        createTimer() {
          new Timer(new Duration(minutes: 30), () {
            count++;
            createTimer();
          });
        }

        createTimer();
        expect(() => async.flushTimers(timeout: new Duration(hours: 2)),
            throwsStateError);
        expect(count, 4);
      });
    });

    test('should time out periodic timers', () {
      new FakeAsync().run((async) {
        new Timer.periodic(
            new Duration(minutes: 30), expectAsync1((_) {}, count: 2));
        expect(() => async.flushTimers(timeout: new Duration(hours: 1)),
            throwsStateError);
      });
    });

    test('should flush periodic timers', () {
      new FakeAsync().run((async) {
        var count = 0;
        new Timer.periodic(new Duration(minutes: 30), (timer) {
          if (count == 3) timer.cancel();
          count++;
        });
        async.flushTimers(timeout: new Duration(hours: 20));
        expect(count, 4);
      });
    });

    test('should compute absolute timeout as elapsed + timeout', () {
      new FakeAsync().run((async) {
        var count = 0;
        createTimer() {
          new Timer(new Duration(minutes: 30), () {
            count++;
            if (count < 4) createTimer();
          });
        }

        createTimer();
        async.elapse(new Duration(hours: 1));
        async.flushTimers(timeout: new Duration(hours: 1));
        expect(count, 4);
      });
    });
  });

  group('stats', () {
    test('should report the number of pending microtasks', () {
      new FakeAsync().run((async) {
        expect(async.microtaskCount, 0);
        scheduleMicrotask(() => null);
        expect(async.microtaskCount, 1);
        scheduleMicrotask(() => null);
        expect(async.microtaskCount, 2);
        async.flushMicrotasks();
        expect(async.microtaskCount, 0);
      });
    });

    test('it should report the number of pending periodic timers', () {
      new FakeAsync().run((async) {
        expect(async.periodicTimerCount, 0);
        var timer = new Timer.periodic(new Duration(minutes: 30), (_) {});
        expect(async.periodicTimerCount, 1);
        new Timer.periodic(new Duration(minutes: 20), (_) {});
        expect(async.periodicTimerCount, 2);
        async.elapse(new Duration(minutes: 20));
        expect(async.periodicTimerCount, 2);
        timer.cancel();
        expect(async.periodicTimerCount, 1);
      });
    });

    test('it should report the number of pending non periodic timers', () {
      new FakeAsync().run((async) {
        expect(async.nonPeriodicTimerCount, 0);
        Timer timer = new Timer(new Duration(minutes: 30), () {});
        expect(async.nonPeriodicTimerCount, 1);
        new Timer(new Duration(minutes: 20), () {});
        expect(async.nonPeriodicTimerCount, 2);
        async.elapse(new Duration(minutes: 25));
        expect(async.nonPeriodicTimerCount, 1);
        timer.cancel();
        expect(async.nonPeriodicTimerCount, 0);
      });
    });
  });

  group('timers', () {
    test("should become inactive as soon as they're invoked", () {
      return new FakeAsync().run((async) {
        Timer timer;
        timer = new Timer(elapseBy, expectAsync0(() {
          expect(timer.isActive, isFalse);
        }));

        expect(timer.isActive, isTrue);
        async.elapse(elapseBy);
        expect(timer.isActive, isFalse);
      });
    });
  });

  group('clock', () {
    test('updates following elapse()', () {
      new FakeAsync().run((async) {
        var before = clock.now();
        async.elapse(elapseBy);
        expect(clock.now(), before.add(elapseBy));
      });
    });

    test('updates following elapseBlocking()', () {
      new FakeAsync().run((async) {
        var before = clock.now();
        async.elapseBlocking(elapseBy);
        expect(clock.now(), before.add(elapseBy));
      });
    });

    group('starts at', () {
      test('the time at which the FakeAsync was created', () {
        var start = new DateTime.now();
        new FakeAsync().run((async) {
          expect(clock.now(), _closeToTime(start));
          async.elapse(elapseBy);
          expect(clock.now(), _closeToTime(start.add(elapseBy)));
        });
      });

      test('the value of clock.now()', () {
        var start = new DateTime(1990, 8, 11);
        withClock(new Clock.fixed(start), () {
          new FakeAsync().run((async) {
            expect(clock.now(), start);
            async.elapse(elapseBy);
            expect(clock.now(), start.add(elapseBy));
          });
        });
      });

      test('an explicit value', () {
        var start = new DateTime(1990, 8, 11);
        new FakeAsync(initialTime: start).run((async) {
          expect(clock.now(), start);
          async.elapse(elapseBy);
          expect(clock.now(), start.add(elapseBy));
        });
      });
    });
  });
}

/// Returns a matcher that asserts that a [DateTime] is within 100ms of
/// [expected].
Matcher _closeToTime(DateTime expected) => predicate(
    (actual) =>
        expected.difference(actual as DateTime).inMilliseconds.abs() < 100,
    "is close to $expected");

/// A wrapper for [neverCalled] that works around sdk#33015.
void Function() get neverCalledVoid {
  var function = neverCalled;
  return () => neverCalled();
}
