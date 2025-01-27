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

void main() {
  final initialTime = DateTime(2000);
  final elapseBy = const Duration(days: 1);

  test('should set initial time', () {
    expect(FakeAsync().getClock(initialTime).now(), initialTime);
  });

  group('elapseBlocking', () {
    test('should elapse time without calling timers or microtasks', () {
      FakeAsync()
        ..run((_) {
          // Do not use [neverCalled] from package:test.
          // It schedules timers to "pump the event loop",
          // which stalls the test if you don't call `elapse` or `flushTimers`.
          final notCalled = expectAsync0(count: 0, () {});
          scheduleMicrotask(notCalled);
          Timer(elapseBy ~/ 2, notCalled);
          Timer(Duration.zero, expectAsync0(count: 0, notCalled));
        })
        ..elapseBlocking(elapseBy);
    });

    test('should elapse time by the specified amount', () {
      final async = FakeAsync()..elapseBlocking(elapseBy);
      expect(async.elapsed, elapseBy);
    });

    test('should throw when called with a negative duration', () {
      expect(() => FakeAsync().elapseBlocking(const Duration(days: -1)),
          throwsArgumentError);
    });
  });

  group('elapse', () {
    test('should elapse time by the specified amount', () {
      FakeAsync().run((async) {
        async.elapse(elapseBy);
        expect(async.elapsed, elapseBy);
      });
    });

    test('should throw ArgumentError when called with a negative duration', () {
      expect(() => FakeAsync().elapse(const Duration(days: -1)),
          throwsArgumentError);
    });

    test('should throw when called before previous call is complete', () {
      FakeAsync().run((async) {
        Timer(elapseBy ~/ 2, expectAsync0(() {
          expect(() => async.elapse(elapseBy), throwsStateError);
        }));
        async.elapse(elapseBy);
      });
    });

    group('when creating timers', () {
      test('should call timers expiring before or at end time', () {
        FakeAsync().run((async) {
          Timer(elapseBy ~/ 2, expectAsync0(() {}));
          Timer(elapseBy, expectAsync0(() {}));
          async.elapse(elapseBy);
        });
      });

      test('should call timers expiring due to elapseBlocking', () {
        FakeAsync().run((async) {
          Timer(elapseBy, () => async.elapseBlocking(elapseBy));
          Timer(elapseBy * 2, expectAsync0(() {}));
          async.elapse(elapseBy);
          expect(async.elapsed, elapseBy * 2);
        });
      });

      test('should call timers at their scheduled time', () {
        FakeAsync().run((async) {
          Timer(elapseBy ~/ 2, expectAsync0(() {
            expect(async.elapsed, elapseBy ~/ 2);
          }));

          final periodicCalledAt = <Duration>[];
          Timer.periodic(
              elapseBy ~/ 2, (_) => periodicCalledAt.add(async.elapsed));

          async.elapse(elapseBy);
          expect(periodicCalledAt, [elapseBy ~/ 2, elapseBy]);
        });
      });

      test('should not call timers expiring after end time', () {
        FakeAsync().run((async) {
          Timer(elapseBy * 2, neverCalled);
          async.elapse(elapseBy);
        });
      });

      test('should not call canceled timers', () {
        FakeAsync().run((async) {
          Timer(elapseBy ~/ 2, neverCalled).cancel();
          async.elapse(elapseBy);
        });
      });

      test('should call periodic timers each time the duration elapses', () {
        FakeAsync().run((async) {
          Timer.periodic(elapseBy ~/ 10, expectAsync1((_) {}, count: 10));
          async.elapse(elapseBy);
        });
      });

      test('should call timers occurring at the same time in FIFO order', () {
        FakeAsync().run((async) {
          final log = <String>[];
          Timer(elapseBy ~/ 2, () => log.add('1'));
          Timer(elapseBy ~/ 2, () => log.add('2'));
          async.elapse(elapseBy);
          expect(log, ['1', '2']);
        });
      });

      test('should maintain FIFO order even with periodic timers', () {
        FakeAsync().run((async) {
          final log = <String>[];
          Timer.periodic(elapseBy ~/ 2, (_) => log.add('periodic 1'));
          Timer(elapseBy ~/ 2, () => log.add('delayed 1'));
          Timer(elapseBy, () => log.add('delayed 2'));
          Timer.periodic(elapseBy, (_) => log.add('periodic 2'));

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
        FakeAsync().run((async) {
          var microtaskCalls = 0;
          var timerCalls = 0;
          void scheduleMicrotasks() {
            for (var i = 0; i < 5; i++) {
              scheduleMicrotask(() => microtaskCalls++);
            }
          }

          scheduleMicrotasks();
          Timer.periodic(elapseBy ~/ 5, (_) {
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
        FakeAsync().run((async) {
          late Timer constructed;
          constructed = Timer.periodic(elapseBy, expectAsync1((passed) {
            expect(passed, same(constructed));
          }));
          async.elapse(elapseBy);
        });
      });

      test('should call microtasks before advancing time', () {
        FakeAsync().run((async) {
          scheduleMicrotask(expectAsync0(() {
            expect(async.elapsed, Duration.zero);
          }));
          async.elapse(const Duration(minutes: 1));
        });
      });

      test('should add event before advancing time', () {
        FakeAsync().run((async) {
          final controller = StreamController<void>();
          expect(controller.stream.first.then((_) {
            expect(async.elapsed, Duration.zero);
          }), completes);
          controller.add(null);
          async.elapse(const Duration(minutes: 1));
        });
      });

      test('should increase negative duration timers to zero duration', () {
        FakeAsync().run((async) {
          final negativeDuration = const Duration(days: -1);
          Timer(negativeDuration, expectAsync0(() {
            expect(async.elapsed, Duration.zero);
          }));
          async.elapse(const Duration(minutes: 1));
        });
      });

      test('should not be additive with elapseBlocking', () {
        FakeAsync().run((async) {
          Timer(Duration.zero, () => async.elapseBlocking(elapseBy * 5));
          async.elapse(elapseBy);
          expect(async.elapsed, elapseBy * 5);
        });
      });

      group('isActive', () {
        test('should be false after timer is run', () {
          FakeAsync().run((async) {
            final timer = Timer(elapseBy ~/ 2, () {});
            async.elapse(elapseBy);
            expect(timer.isActive, isFalse);
          });
        });

        test('should be true after periodic timer is run', () {
          FakeAsync().run((async) {
            final timer = Timer.periodic(elapseBy ~/ 2, (_) {});
            async.elapse(elapseBy);
            expect(timer.isActive, isTrue);
          });
        });

        test('should be false after timer is canceled', () {
          FakeAsync().run((async) {
            final timer = Timer(elapseBy ~/ 2, () {})..cancel();
            expect(timer.isActive, isFalse);
          });
        });
      });

      test('should work with new Future()', () {
        FakeAsync().run((async) {
          Future(expectAsync0(() {}));
          async.elapse(Duration.zero);
        });
      });

      test('should work with Future.delayed', () {
        FakeAsync().run((async) {
          Future.delayed(elapseBy, expectAsync0(() {}));
          async.elapse(elapseBy);
        });
      });

      test('should work with Future.timeout', () {
        FakeAsync().run((async) {
          final completer = Completer<void>();
          expect(completer.future.timeout(elapseBy ~/ 2),
              throwsA(const TypeMatcher<TimeoutException>()));
          async.elapse(elapseBy);
          completer.complete();
        });
      });

      // TODO: Pausing and resuming the timeout Stream doesn't work since
      // it uses `new Stopwatch()`.
      //
      // See https://dartbug.com/18149
      test('should work with Stream.periodic', () {
        FakeAsync().run((async) {
          expect(Stream.periodic(const Duration(minutes: 1), (i) => i),
              emitsInOrder([0, 1, 2]));
          async.elapse(const Duration(minutes: 3));
        });
      });

      test('should work with Stream.timeout', () {
        FakeAsync().run((async) {
          final controller = StreamController<int>();
          final timed = controller.stream.timeout(const Duration(minutes: 2));

          final events = <int>[];
          final errors = <Object>[];
          timed.listen(events.add, onError: errors.add);

          controller.add(0);
          async.elapse(const Duration(minutes: 1));
          expect(events, [0]);

          async.elapse(const Duration(minutes: 1));
          expect(errors, hasLength(1));
          expect(errors.first, const TypeMatcher<TimeoutException>());
        });
      });
    });
  });

  group('flushMicrotasks', () {
    test('should flush a microtask', () {
      FakeAsync().run((async) {
        Future.microtask(expectAsync0(() {}));
        async.flushMicrotasks();
      });
    });

    test('should flush microtasks scheduled by microtasks in order', () {
      FakeAsync().run((async) {
        final log = <int>[];
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
      FakeAsync().run((async) {
        final log = <int>[];
        scheduleMicrotask(() => log.add(1));
        Timer.run(() => log.add(2));
        Timer.periodic(const Duration(seconds: 1), (_) => log.add(2));

        async.flushMicrotasks();
        expect(log, [1]);
      });
    });
  });

  group('flushTimers', () {
    test('should flush timers in FIFO order', () {
      FakeAsync().run((async) {
        final log = <int>[];
        Timer.run(() {
          log.add(1);
          Timer(elapseBy, () => log.add(3));
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
      FakeAsync().run((async) {
        final log = <String>[];
        Timer(const Duration(seconds: 2), () => log.add('delayed'));
        Timer.periodic(const Duration(seconds: 1), (_) => log.add('periodic'));

        async.flushTimers(flushPeriodicTimers: false);
        expect(log, ['periodic', 'delayed', 'periodic']);
      });
    });

    test(
        'should run collateral periodic timers with periodic first '
        'if scheduled first', () {
      FakeAsync().run((async) {
        final log = <String>[];
        Timer.periodic(const Duration(seconds: 1), (_) => log.add('periodic'));
        Timer(const Duration(seconds: 2), () => log.add('delayed'));

        async.flushTimers(flushPeriodicTimers: false);
        expect(log, ['periodic', 'periodic', 'delayed']);
      });
    });

    test('should time out', () {
      FakeAsync().run((async) {
        // Schedule 3 timers. All but the last one should fire.
        for (var delay in [30, 60, 90]) {
          Timer(Duration(minutes: delay),
              expectAsync0(() {}, count: delay == 90 ? 0 : 1));
        }

        expect(() => async.flushTimers(), throwsStateError);
      });
    });

    test('should time out a chain of timers', () {
      FakeAsync().run((async) {
        var count = 0;
        void createTimer() {
          Timer(const Duration(minutes: 30), () {
            count++;
            createTimer();
          });
        }

        createTimer();
        expect(() => async.flushTimers(timeout: const Duration(hours: 2)),
            throwsStateError);
        expect(count, 4);
      });
    });

    test('should time out periodic timers', () {
      FakeAsync().run((async) {
        Timer.periodic(
            const Duration(minutes: 30), expectAsync1((_) {}, count: 2));
        expect(() => async.flushTimers(timeout: const Duration(hours: 1)),
            throwsStateError);
      });
    });

    test('should flush periodic timers', () {
      FakeAsync().run((async) {
        var count = 0;
        Timer.periodic(const Duration(minutes: 30), (timer) {
          if (count == 3) timer.cancel();
          count++;
        });
        async.flushTimers(timeout: const Duration(hours: 20));
        expect(count, 4);
      });
    });

    test('should compute absolute timeout as elapsed + timeout', () {
      FakeAsync().run((async) {
        var count = 0;
        void createTimer() {
          Timer(const Duration(minutes: 30), () {
            count++;
            if (count < 4) createTimer();
          });
        }

        createTimer();
        async
          ..elapse(const Duration(hours: 1))
          ..flushTimers(timeout: const Duration(hours: 1));
        expect(count, 4);
      });
    });
  });

  group('stats', () {
    test('should report the number of pending microtasks', () {
      FakeAsync().run((async) {
        expect(async.microtaskCount, 0);
        scheduleMicrotask(() {});
        expect(async.microtaskCount, 1);
        scheduleMicrotask(() {});
        expect(async.microtaskCount, 2);
        async.flushMicrotasks();
        expect(async.microtaskCount, 0);
      });
    });

    test('it should report the number of pending periodic timers', () {
      FakeAsync().run((async) {
        expect(async.periodicTimerCount, 0);
        final timer = Timer.periodic(const Duration(minutes: 30), (_) {});
        expect(async.periodicTimerCount, 1);
        Timer.periodic(const Duration(minutes: 20), (_) {});
        expect(async.periodicTimerCount, 2);
        async.elapse(const Duration(minutes: 20));
        expect(async.periodicTimerCount, 2);
        timer.cancel();
        expect(async.periodicTimerCount, 1);
      });
    });

    test('it should report the number of pending non periodic timers', () {
      FakeAsync().run((async) {
        expect(async.nonPeriodicTimerCount, 0);
        final timer = Timer(const Duration(minutes: 30), () {});
        expect(async.nonPeriodicTimerCount, 1);
        Timer(const Duration(minutes: 20), () {});
        expect(async.nonPeriodicTimerCount, 2);
        async.elapse(const Duration(minutes: 25));
        expect(async.nonPeriodicTimerCount, 1);
        timer.cancel();
        expect(async.nonPeriodicTimerCount, 0);
      });
    });

    test('should report debugging information of pending timers', () {
      FakeAsync().run((fakeAsync) {
        expect(fakeAsync.pendingTimers, isEmpty);
        final nonPeriodic =
            Timer(const Duration(seconds: 1), () {}) as FakeTimer;
        final periodic =
            Timer.periodic(const Duration(seconds: 2), (Timer timer) {})
                as FakeTimer;
        final debugInfo = fakeAsync.pendingTimers;
        expect(debugInfo.length, 2);
        expect(
          debugInfo,
          containsAll([
            nonPeriodic,
            periodic,
          ]),
        );

        const thisFileName = 'fake_async_test.dart';
        expect(nonPeriodic.debugString, contains(':01.0'));
        expect(nonPeriodic.debugString, contains('periodic: false'));
        expect(nonPeriodic.debugString, contains(thisFileName));
        expect(periodic.debugString, contains(':02.0'));
        expect(periodic.debugString, contains('periodic: true'));
        expect(periodic.debugString, contains(thisFileName));
      });
    });

    test(
        'should report debugging information of pending timers excluding '
        'stack traces', () {
      FakeAsync(includeTimerStackTrace: false).run((fakeAsync) {
        expect(fakeAsync.pendingTimers, isEmpty);
        final nonPeriodic =
            Timer(const Duration(seconds: 1), () {}) as FakeTimer;
        final periodic =
            Timer.periodic(const Duration(seconds: 2), (Timer timer) {})
                as FakeTimer;
        final debugInfo = fakeAsync.pendingTimers;
        expect(debugInfo.length, 2);
        expect(
          debugInfo,
          containsAll([
            nonPeriodic,
            periodic,
          ]),
        );

        const thisFileName = 'fake_async_test.dart';
        expect(nonPeriodic.debugString, contains(':01.0'));
        expect(nonPeriodic.debugString, contains('periodic: false'));
        expect(nonPeriodic.debugString, isNot(contains(thisFileName)));
        expect(periodic.debugString, contains(':02.0'));
        expect(periodic.debugString, contains('periodic: true'));
        expect(periodic.debugString, isNot(contains(thisFileName)));
      });
    });
  });

  group('timers', () {
    test("should become inactive as soon as they're invoked", () {
      return FakeAsync().run((async) {
        late Timer timer;
        timer = Timer(elapseBy, expectAsync0(() {
          expect(timer.isActive, isFalse);
        }));

        expect(timer.isActive, isTrue);
        async.elapse(elapseBy);
        expect(timer.isActive, isFalse);
      });
    });

    test('should increment tick in a non-periodic timer', () {
      return FakeAsync().run((async) {
        late Timer timer;
        timer = Timer(elapseBy, expectAsync0(() {
          expect(timer.tick, 1);
        }));

        expect(timer.tick, 0);
        async.elapse(elapseBy);
      });
    });

    test('should increment tick in a periodic timer', () {
      return FakeAsync().run((async) {
        final ticks = <int>[];
        Timer.periodic(
            elapseBy,
            expectAsync1((timer) {
              ticks.add(timer.tick);
            }, count: 2));
        async
          ..elapse(elapseBy)
          ..elapse(elapseBy);
        expect(ticks, [1, 2]);
      });
    });

    test('should update periodic timer state before invoking callback', () {
      // Regression test for: https://github.com/dart-lang/fake_async/issues/88
      FakeAsync().run((async) {
        final log = <String>[];
        Timer.periodic(const Duration(seconds: 2), (timer) {
          log.add('periodic ${timer.tick}');
          async.elapse(Duration.zero);
        });
        Timer(const Duration(seconds: 3), () {
          log.add('single');
        });

        async.flushTimers(flushPeriodicTimers: false);
        expect(log, ['periodic 1', 'single']);
      });
    });

    test('can increment periodic timer tick by more than one', () {
      final async = FakeAsync();
      final ticks = <(int ms, int tick)>[];
      final timer = async
          .run((_) => Timer.periodic(const Duration(milliseconds: 1000), (t) {
                final tick = t.tick;
                ticks.add((async.elapsed.inMilliseconds, tick));
              }));
      expect(timer.tick, 0);
      expect(ticks, isEmpty);

      // Run timer once.
      async.elapse(const Duration(milliseconds: 1000));
      expect(ticks, [(1000, 1)]);
      expect(timer.tick, 1);
      expect(async.elapsed, const Duration(milliseconds: 1000));
      ticks.clear();

      // Block past two timer ticks without running events.
      async.elapseBlocking(const Duration(milliseconds: 2300));
      expect(async.elapsed, const Duration(milliseconds: 3300));
      // Runs no events.
      expect(ticks, isEmpty);

      // Run due timers only. Time does not advance.
      async.flushTimers(flushPeriodicTimers: false);
      expect(ticks, [(3300, 3)]); // Timer ran only once.
      expect(timer.tick, 3);
      expect(async.elapsed, const Duration(milliseconds: 3300));
      ticks.clear();

      // Pass more time, but without reaching tick 4.
      async.elapse(const Duration(milliseconds: 300));
      expect(ticks, isEmpty);
      expect(timer.tick, 3);
      expect(async.elapsed, const Duration(milliseconds: 3600));

      // Pass next timer.
      async.elapse(const Duration(milliseconds: 500));
      expect(ticks, [(4000, 4)]);
      expect(timer.tick, 4);
      expect(async.elapsed, const Duration(milliseconds: 4100));
    });

    test('can run elapseBlocking during periodic timer callback', () {
      final async = FakeAsync();
      final ticks = <(int ms, int tick)>[];
      final timer = async
          .run((_) => Timer.periodic(const Duration(milliseconds: 1000), (t) {
                ticks.add((async.elapsed.inMilliseconds, t.tick));
                if (t.tick == 2) {
                  async.elapseBlocking(const Duration(milliseconds: 2300));
                  // Log time at end of callback as well.
                  ticks.add((async.elapsed.inMilliseconds, t.tick));
                }
              }));
      expect(timer.tick, 0);
      expect(ticks, isEmpty);

      // Run timer once.
      async.elapse(const Duration(milliseconds: 1100));
      expect(ticks, [(1000, 1)]);
      expect(timer.tick, 1); // Didn't tick yet.
      expect(async.elapsed, const Duration(milliseconds: 1100));
      ticks.clear();

      // Run timer once more.
      // This blocks for additional 2300 ms, making timer due again,
      // and `flushTimers` will run it.
      async.elapse(const Duration(milliseconds: 1100));
      expect(ticks, [(2000, 2), (4300, 2), (4300, 4)]);
      expect(timer.tick, 4);
      expect(async.elapsed, const Duration(milliseconds: 4300));
      ticks.clear();

      // Pass more time, but without reaching tick 5.
      async.elapse(const Duration(milliseconds: 300));
      expect(ticks, isEmpty);
      expect(timer.tick, 4);
      expect(async.elapsed, const Duration(milliseconds: 4600));

      // Pass next timer normally.
      async.elapse(const Duration(milliseconds: 500));
      expect(ticks, [(5000, 5)]);
      expect(timer.tick, 5);
      expect(async.elapsed, const Duration(milliseconds: 5100));
    });
  });

  group('clock', () {
    test('updates following elapse()', () {
      FakeAsync().run((async) {
        final before = clock.now();
        async.elapse(elapseBy);
        expect(clock.now(), before.add(elapseBy));
      });
    });

    test('updates following elapseBlocking()', () {
      FakeAsync().run((async) {
        final before = clock.now();
        async.elapseBlocking(elapseBy);
        expect(clock.now(), before.add(elapseBy));
      });
    });

    group('starts at', () {
      test('the time at which the FakeAsync was created', () {
        final start = DateTime.now();
        FakeAsync().run((async) {
          expect(clock.now(), _closeToTime(start));
          async.elapse(elapseBy);
          expect(clock.now(), _closeToTime(start.add(elapseBy)));
        });
      });

      test('the value of clock.now()', () {
        final start = DateTime(1990, 8, 11);
        withClock(Clock.fixed(start), () {
          FakeAsync().run((async) {
            expect(clock.now(), start);
            async.elapse(elapseBy);
            expect(clock.now(), start.add(elapseBy));
          });
        });
      });

      test('an explicit value', () {
        final start = DateTime(1990, 8, 11);
        FakeAsync(initialTime: start).run((async) {
          expect(clock.now(), start);
          async.elapse(elapseBy);
          expect(clock.now(), start.add(elapseBy));
        });
      });
    });
  });

  group('zone', () {
    test('can be used directly', () {
      final async = FakeAsync();
      final zone = async.run((_) => Zone.current);
      final log = <String>[];
      zone
        ..scheduleMicrotask(() {
          log.add('microtask');
        })
        ..createPeriodicTimer(elapseBy, (_) {
          log.add('periodicTimer');
        })
        ..createTimer(elapseBy, () {
          log.add('timer');
        });
      expect(log, isEmpty);
      async.elapse(elapseBy);
      expect(log, ['microtask', 'periodicTimer', 'timer']);
    });

    test('runs in outer zone, passes run/register/error through', () {
      var counter = 0;
      final log = <String>[];
      final (async, zone) = runZoned(
          () => fakeAsync((newAsync) {
                return (newAsync, Zone.current);
              }),
          zoneSpecification:
              ZoneSpecification(registerCallback: <R>(s, p, z, f) {
            final id = ++counter;
            log.add('r0(#$id)');
            f = p.registerCallback(z, f);
            return () {
              log.add('#$id()');
              return f();
            };
          }, registerUnaryCallback: <R, P>(s, p, z, f) {
            final id = ++counter;
            log.add('r1(#$id)');
            f = p.registerUnaryCallback(z, f);
            return (v) {
              log.add('#$id(_)');
              return f(v);
            };
          }, run: <R>(s, p, z, f) {
            log.add('run0');
            return p.run(z, f);
          }, runUnary: <R, P>(s, p, z, f, v) {
            log.add('run1');
            return p.runUnary(z, f, v);
          }, handleUncaughtError: (s, p, z, e, _) {
            log.add('ERR($e)');
          }));

      zone.run(() {
        log.clear(); // Forget everything until here.
        scheduleMicrotask(() {});
      });
      expect(log, ['r0(#1)']);

      zone.run(() {
        log.clear();
        Timer(elapseBy, () {});
      });
      expect(log, ['r0(#2)']);

      zone.run(() {
        log.clear();
        Timer.periodic(elapseBy * 2, (t) {
          if (t.tick == 2) {
            throw 'periodic timer error'; // ignore: only_throw_errors
          }
        });
      });
      expect(log, ['r1(#3)']);
      log.clear();

      async.flushMicrotasks();
      // Some zone implementations may introduce extra `run` calls.
      expect(log.tail(2), ['run0', '#1()']);
      log.clear();

      async.elapse(elapseBy);
      expect(log.tail(2), ['run0', '#2()']);
      log.clear();

      async.elapse(elapseBy);
      expect(log.tail(2), ['run1', '#3(_)']);

      zone.run(() {
        log.clear();
        scheduleMicrotask(() {
          throw 'microtask error'; // ignore: only_throw_errors
        });
        Timer(elapseBy, () {
          throw 'timer error'; // ignore: only_throw_errors
        });
      });
      expect(log, ['r0(#4)', 'r0(#5)']);
      log.clear();

      async.flushMicrotasks();
      expect(log.tail(3), ['run0', '#4()', 'ERR(microtask error)']);
      log.clear();

      async.elapse(elapseBy);
      expect(log.tail(3), ['run0', '#5()', 'ERR(timer error)']);
      log.clear();

      async.elapse(elapseBy);
      expect(log.tail(3), ['run1', '#3(_)', 'ERR(periodic timer error)']);
      log.clear();
    });
  });
}

/// Returns a matcher that asserts that a [DateTime] is within 100ms of
/// [expected].
Matcher _closeToTime(DateTime expected) => predicate(
    (actual) =>
        expected.difference(actual as DateTime).inMilliseconds.abs() < 100,
    'is close to $expected');

extension<T> on List<T> {
  List<T> tail(int count) => sublist(length - count);
}
