// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE filevents.

// TODO(nweiz): Get rid of this when https://codereview.chromium.org/1241723003/
// lands.

import "dart:async";

import "package:test/src/util/stream_queue.dart";
import "package:test/test.dart";

main() {
  group("source stream", () {
    test("is listened to on first request, paused between requests", () async {
      var controller = new StreamController();
      var events = new StreamQueue<int>(controller.stream);
      await flushMicrotasks();
      expect(controller.hasListener, isFalse);

      var next = events.next;
      expect(controller.hasListener, isTrue);
      expect(controller.isPaused, isFalse);

      controller.add(1);

      expect(await next, 1);
      expect(controller.hasListener, isTrue);
      expect(controller.isPaused, isTrue);

      next = events.next;
      expect(controller.hasListener, isTrue);
      expect(controller.isPaused, isFalse);

      controller.add(2);

      expect(await next, 2);
      expect(controller.hasListener, isTrue);
      expect(controller.isPaused, isTrue);

      events.cancel();
      expect(controller.hasListener, isFalse);
    });
  });

  group("next operation", () {
    test("simple sequence of requests", () async {
      var events = new StreamQueue<int>(createStream());
      for (int i = 1; i <= 4; i++) {
        expect(await events.next, i);
      }
      expect(events.next, throwsStateError);
    });

    test("multiple requests at the same time", () async {
      var events = new StreamQueue<int>(createStream());
      var result = await Future.wait(
          [events.next, events.next, events.next, events.next]);
      expect(result, [1, 2, 3, 4]);
      await events.cancel();
    });

    test("sequence of requests with error", () async {
      var events = new StreamQueue<int>(createErrorStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(events.next, throwsA("To err is divine!"));
      expect(await events.next, 4);
      await events.cancel();
    });
  });

  group("skip operation", () {
    test("of two elements in the middle of sequence", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.skip(2), 0);
      expect(await events.next, 4);
      await events.cancel();
    });

    test("with negative/bad arguments throws", () async {
      var events = new StreamQueue<int>(createStream());
      expect(() => events.skip(-1), throwsArgumentError);
      // A non-int throws either a type error or an argument error,
      // depending on whether it's checked mode or not.
      expect(await events.next, 1);  // Did not consume event.
      expect(() => events.skip(-1), throwsArgumentError);
      expect(await events.next, 2);  // Did not consume event.
      await events.cancel();
    });

    test("of 0 elements works", () async {
      var events = new StreamQueue<int>(createStream());
      expect(events.skip(0), completion(0));
      expect(events.next, completion(1));
      expect(events.skip(0), completion(0));
      expect(events.next, completion(2));
      expect(events.skip(0), completion(0));
      expect(events.next, completion(3));
      expect(events.skip(0), completion(0));
      expect(events.next, completion(4));
      expect(events.skip(0), completion(0));
      expect(events.skip(5), completion(5));
      expect(events.next, throwsStateError);
      await events.cancel();
    });

    test("of too many events ends at stream start", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.skip(6), 2);
      await events.cancel();
    });

    test("of too many events after some events", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(await events.skip(6), 4);
      await events.cancel();
    });

    test("of too many events ends at stream end", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(await events.next, 3);
      expect(await events.next, 4);
      expect(await events.skip(2), 2);
      await events.cancel();
    });

    test("of events with error", () async {
      var events = new StreamQueue<int>(createErrorStream());
      expect(events.skip(4), throwsA("To err is divine!"));
      expect(await events.next, 4);
      await events.cancel();
    });

    test("of events with error, and skip again after", () async {
      var events = new StreamQueue<int>(createErrorStream());
      expect(events.skip(4), throwsA("To err is divine!"));
      expect(events.skip(2), completion(1));
      await events.cancel();
    });
    test("multiple skips at same time complete in order.", () async {
      var events = new StreamQueue<int>(createStream());
      var skip1 = events.skip(1);
      var skip2 = events.skip(0);
      var skip3 = events.skip(4);
      var skip4 = events.skip(1);
      var index = 0;
      // Check that futures complete in order.
      sequence(expectedValue, sequenceIndex) => (value) {
        expect(value, expectedValue);
        expect(index, sequenceIndex);
        index++;
      };
      await Future.wait([skip1.then(sequence(0, 0)),
                         skip2.then(sequence(0, 1)),
                         skip3.then(sequence(1, 2)),
                         skip4.then(sequence(1, 3))]);
      await events.cancel();
    });
  });

  group("take operation", () {
    test("as simple take of events", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.take(2), [2, 3]);
      expect(await events.next, 4);
      await events.cancel();
    });

    test("of 0 events", () async {
      var events = new StreamQueue<int>(createStream());
      expect(events.take(0), completion([]));
      expect(events.next, completion(1));
      expect(events.take(0), completion([]));
      expect(events.next, completion(2));
      expect(events.take(0), completion([]));
      expect(events.next, completion(3));
      expect(events.take(0), completion([]));
      expect(events.next, completion(4));
      expect(events.take(0), completion([]));
      expect(events.take(5), completion([]));
      expect(events.next, throwsStateError);
      await events.cancel();
    });

    test("with bad arguments throws", () async {
      var events = new StreamQueue<int>(createStream());
      expect(() => events.take(-1), throwsArgumentError);
      expect(await events.next, 1);  // Did not consume event.
      expect(() => events.take(-1), throwsArgumentError);
      expect(await events.next, 2);  // Did not consume event.
      await events.cancel();
    });

    test("of too many arguments", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.take(6), [1, 2, 3, 4]);
      await events.cancel();
    });

    test("too large later", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(await events.take(6), [3, 4]);
      await events.cancel();
    });

    test("error", () async {
      var events = new StreamQueue<int>(createErrorStream());
      expect(events.take(4), throwsA("To err is divine!"));
      expect(await events.next, 4);
      await events.cancel();
    });
  });

  group("rest operation", () {
    test("after single next", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.rest.toList(), [2, 3, 4]);
    });

    test("at start", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.rest.toList(), [1, 2, 3, 4]);
    });

    test("at end", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(await events.next, 3);
      expect(await events.next, 4);
      expect(await events.rest.toList(), isEmpty);
    });

    test("after end", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(await events.next, 3);
      expect(await events.next, 4);
      expect(events.next, throwsStateError);
      expect(await events.rest.toList(), isEmpty);
    });

    test("after receiving done requested before", () async {
      var events = new StreamQueue<int>(createStream());
      var next1 = events.next;
      var next2 = events.next;
      var next3 = events.next;
      var rest = events.rest;
      for (int i = 0; i < 10; i++) {
        await flushMicrotasks();
      }
      expect(await next1, 1);
      expect(await next2, 2);
      expect(await next3, 3);
      expect(await rest.toList(), [4]);
    });

    test("with an error event error", () async {
      var events = new StreamQueue<int>(createErrorStream());
      expect(await events.next, 1);
      var rest = events.rest;
      var events2 = new StreamQueue(rest);
      expect(await events2.next, 2);
      expect(events2.next, throwsA("To err is divine!"));
      expect(await events2.next, 4);
    });

    test("closes the events, prevents other operations", () async {
      var events = new StreamQueue<int>(createStream());
      var stream = events.rest;
      expect(() => events.next, throwsStateError);
      expect(() => events.skip(1), throwsStateError);
      expect(() => events.take(1), throwsStateError);
      expect(() => events.rest, throwsStateError);
      expect(() => events.cancel(), throwsStateError);
      expect(stream.toList(), completion([1, 2, 3, 4]));
    });

    test("forwards to underlying stream", () async {
      var cancel = new Completer();
      var controller = new StreamController(onCancel: () => cancel.future);
      var events = new StreamQueue<int>(controller.stream);
      expect(controller.hasListener, isFalse);
      var next = events.next;
      expect(controller.hasListener, isTrue);
      expect(controller.isPaused, isFalse);

      controller.add(1);
      expect(await next, 1);
      expect(controller.isPaused, isTrue);

      var rest = events.rest;
      var subscription = rest.listen(null);
      expect(controller.hasListener, isTrue);
      expect(controller.isPaused, isFalse);

      var lastEvent;
      subscription.onData((value) => lastEvent = value);

      controller.add(2);

      await flushMicrotasks();
      expect(lastEvent, 2);
      expect(controller.hasListener, isTrue);
      expect(controller.isPaused, isFalse);

      subscription.pause();
      expect(controller.isPaused, isTrue);

      controller.add(3);

      await flushMicrotasks();
      expect(lastEvent, 2);
      subscription.resume();

      await flushMicrotasks();
      expect(lastEvent, 3);

      var cancelFuture = subscription.cancel();
      expect(controller.hasListener, isFalse);
      cancel.complete(42);
      expect(cancelFuture, completion(42));
    });
  });

  group("cancel operation", () {
    test("closes the events, prevents any other operation", () async {
      var events = new StreamQueue<int>(createStream());
      await events.cancel();
      expect(() => events.next, throwsStateError);
      expect(() => events.skip(1), throwsStateError);
      expect(() => events.take(1), throwsStateError);
      expect(() => events.rest, throwsStateError);
      expect(() => events.cancel(), throwsStateError);
    });

    test("cancels underlying subscription when called before any event",
        () async {
      var cancelFuture = new Future.value(42);
      var controller = new StreamController(onCancel: () => cancelFuture);
      var events = new StreamQueue<int>(controller.stream);
      expect(await events.cancel(), 42);
    });

    test("cancels underlying subscription, returns result", () async {
      var cancelFuture = new Future.value(42);
      var controller = new StreamController(onCancel: () => cancelFuture);
      var events = new StreamQueue<int>(controller.stream);
      controller.add(1);
      expect(await events.next, 1);
      expect(await events.cancel(), 42);
    });

    group("with immediate: true", () {
      test("closes the events, prevents any other operation", () async {
        var events = new StreamQueue<int>(createStream());
        await events.cancel(immediate: true);
        expect(() => events.next, throwsStateError);
        expect(() => events.skip(1), throwsStateError);
        expect(() => events.take(1), throwsStateError);
        expect(() => events.rest, throwsStateError);
        expect(() => events.cancel(), throwsStateError);
      });

      test("cancels the underlying subscription immediately", () async {
        var controller = new StreamController();
        controller.add(1);

        var events = new StreamQueue<int>(controller.stream);
        expect(await events.next, 1);
        expect(controller.hasListener, isTrue);

        events.cancel(immediate: true);
        await expect(controller.hasListener, isFalse);
      });

      test("cancels the underlying subscription when called before any event",
          () async {
        var cancelFuture = new Future.value(42);
        var controller = new StreamController(onCancel: () => cancelFuture);

        var events = new StreamQueue<int>(controller.stream);
        expect(await events.cancel(immediate: true), 42);
      });

      test("closes pending requests", () async {
        var events = new StreamQueue<int>(createStream());
        expect(await events.next, 1);
        expect(events.next, throwsStateError);
        expect(events.hasNext, completion(isFalse));

        await events.cancel(immediate: true);
      });

      test("returns the result of closing the underlying subscription",
          () async {
        var controller = new StreamController(
            onCancel: () => new Future.value(42));
        var events = new StreamQueue<int>(controller.stream);
        expect(await events.cancel(immediate: true), 42);
      });

      test("listens and then cancels a stream that hasn't been listened to yet",
          () async {
        var wasListened = false;
        var controller = new StreamController(
            onListen: () => wasListened = true);
        var events = new StreamQueue<int>(controller.stream);
        expect(wasListened, isFalse);
        expect(controller.hasListener, isFalse);

        await events.cancel(immediate: true);
        expect(wasListened, isTrue);
        expect(controller.hasListener, isFalse);
      });
    });
  });

  group("hasNext operation", () {
    test("true at start", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.hasNext, isTrue);
    });

    test("true after start", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.hasNext, isTrue);
    });

    test("true at end", () async {
      var events = new StreamQueue<int>(createStream());
      for (int i = 1; i <= 4; i++) {
        expect(await events.next, i);
      }
      expect(await events.hasNext, isFalse);
    });

    test("true when enqueued", () async {
      var events = new StreamQueue<int>(createStream());
      var values = [];
      for (int i = 1; i <= 3; i++) {
        events.next.then(values.add);
      }
      expect(values, isEmpty);
      expect(await events.hasNext, isTrue);
      expect(values, [1, 2, 3]);
    });

    test("false when enqueued", () async {
      var events = new StreamQueue<int>(createStream());
      var values = [];
      for (int i = 1; i <= 4; i++) {
        events.next.then(values.add);
      }
      expect(values, isEmpty);
      expect(await events.hasNext, isFalse);
      expect(values, [1, 2, 3, 4]);
    });

    test("true when data event", () async {
      var controller = new StreamController();
      var events = new StreamQueue<int>(controller.stream);

      var hasNext;
      events.hasNext.then((result) { hasNext = result; });
      await flushMicrotasks();
      expect(hasNext, isNull);
      controller.add(42);
      expect(hasNext, isNull);
      await flushMicrotasks();
      expect(hasNext, isTrue);
    });

    test("true when error event", () async {
      var controller = new StreamController();
      var events = new StreamQueue<int>(controller.stream);

      var hasNext;
      events.hasNext.then((result) { hasNext = result; });
      await flushMicrotasks();
      expect(hasNext, isNull);
      controller.addError("BAD");
      expect(hasNext, isNull);
      await flushMicrotasks();
      expect(hasNext, isTrue);
      expect(events.next, throwsA("BAD"));
    });

    test("- hasNext after hasNext", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.hasNext, true);
      expect(await events.hasNext, true);
      expect(await events.next, 1);
      expect(await events.hasNext, true);
      expect(await events.hasNext, true);
      expect(await events.next, 2);
      expect(await events.hasNext, true);
      expect(await events.hasNext, true);
      expect(await events.next, 3);
      expect(await events.hasNext, true);
      expect(await events.hasNext, true);
      expect(await events.next, 4);
      expect(await events.hasNext, false);
      expect(await events.hasNext, false);
    });

    test("- next after true", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.hasNext, true);
      expect(await events.next, 2);
      expect(await events.next, 3);
    });

    test("- next after true, enqueued", () async {
      var events = new StreamQueue<int>(createStream());
      var responses = [];
      events.next.then(responses.add);
      events.hasNext.then(responses.add);
      events.next.then(responses.add);
      do {
        await flushMicrotasks();
      } while (responses.length < 3);
      expect(responses, [1, true, 2]);
    });

    test("- skip 0 after true", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.hasNext, true);
      expect(await events.skip(0), 0);
      expect(await events.next, 2);
    });

    test("- skip 1 after true", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.hasNext, true);
      expect(await events.skip(1), 0);
      expect(await events.next, 3);
    });

    test("- skip 2 after true", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.hasNext, true);
      expect(await events.skip(2), 0);
      expect(await events.next, 4);
    });

    test("- take 0 after true", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.hasNext, true);
      expect(await events.take(0), isEmpty);
      expect(await events.next, 2);
    });

    test("- take 1 after true", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.hasNext, true);
      expect(await events.take(1), [2]);
      expect(await events.next, 3);
    });

    test("- take 2 after true", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.hasNext, true);
      expect(await events.take(2), [2, 3]);
      expect(await events.next, 4);
    });

    test("- rest after true", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.hasNext, true);
      var stream = events.rest;
      expect(await stream.toList(), [2, 3, 4]);
    });

    test("- rest after true, at last", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(await events.next, 3);
      expect(await events.hasNext, true);
      var stream = events.rest;
      expect(await stream.toList(), [4]);
    });

    test("- rest after false", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(await events.next, 3);
      expect(await events.next, 4);
      expect(await events.hasNext, false);
      var stream = events.rest;
      expect(await stream.toList(), isEmpty);
    });

    test("- cancel after true on data", () async {
      var events = new StreamQueue<int>(createStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(await events.hasNext, true);
      expect(await events.cancel(), null);
    });

    test("- cancel after true on error", () async {
      var events = new StreamQueue<int>(createErrorStream());
      expect(await events.next, 1);
      expect(await events.next, 2);
      expect(await events.hasNext, true);
      expect(await events.cancel(), null);
    });
  });

  group("fork operation", () {
    test("produces a stream queue with the same events", () async {
      var queue1 = new StreamQueue<int>(createStream());
      var queue2 = queue1.fork();

      expect(await queue1.next, 1);
      expect(await queue1.next, 2);
      expect(await queue1.next, 3);
      expect(await queue1.next, 4);
      expect(await queue1.hasNext, isFalse);

      expect(await queue2.next, 1);
      expect(await queue2.next, 2);
      expect(await queue2.next, 3);
      expect(await queue2.next, 4);
      expect(await queue2.hasNext, isFalse);
    });

    test("produces a stream queue with the same errors", () async {
      var queue1 = new StreamQueue<int>(createErrorStream());
      var queue2 = queue1.fork();

      expect(await queue1.next, 1);
      expect(await queue1.next, 2);
      expect(queue1.next, throwsA("To err is divine!"));
      expect(await queue1.next, 4);
      expect(await queue1.hasNext, isFalse);

      expect(await queue2.next, 1);
      expect(await queue2.next, 2);
      expect(queue2.next, throwsA("To err is divine!"));
      expect(await queue2.next, 4);
      expect(await queue2.hasNext, isFalse);
    });

    test("forks at the current point in the source queue", () {
      var queue1 = new StreamQueue<int>(createStream());

      expect(queue1.next, completion(1));
      expect(queue1.next, completion(2));

      var queue2 = queue1.fork();

      expect(queue1.next, completion(3));
      expect(queue1.next, completion(4));
      expect(queue1.hasNext, completion(isFalse));

      expect(queue2.next, completion(3));
      expect(queue2.next, completion(4));
      expect(queue2.hasNext, completion(isFalse));
    });

    test("can be created after there are pending values", () async {
      var queue1 = new StreamQueue<int>(createStream());
      await flushMicrotasks();

      var queue2 = queue1.fork();
      expect(await queue2.next, 1);
      expect(await queue2.next, 2);
      expect(await queue2.next, 3);
      expect(await queue2.next, 4);
      expect(await queue2.hasNext, isFalse);
    });

    test("multiple forks can be created at different points", () async {
      var queue1 = new StreamQueue<int>(createStream());

      var queue2 = queue1.fork();
      expect(await queue1.next, 1);
      expect(await queue2.next, 1);

      var queue3 = queue1.fork();
      expect(await queue1.next, 2);
      expect(await queue2.next, 2);
      expect(await queue3.next, 2);

      var queue4 = queue1.fork();
      expect(await queue1.next, 3);
      expect(await queue2.next, 3);
      expect(await queue3.next, 3);
      expect(await queue4.next, 3);

      var queue5 = queue1.fork();
      expect(await queue1.next, 4);
      expect(await queue2.next, 4);
      expect(await queue3.next, 4);
      expect(await queue4.next, 4);
      expect(await queue5.next, 4);

      var queue6 = queue1.fork();
      expect(await queue1.hasNext, isFalse);
      expect(await queue2.hasNext, isFalse);
      expect(await queue3.hasNext, isFalse);
      expect(await queue4.hasNext, isFalse);
      expect(await queue5.hasNext, isFalse);
      expect(await queue6.hasNext, isFalse);
    });

    test("same-level forks receive data in the order they were created",
        () async {
      var queue1 = new StreamQueue<int>(createStream());
      var queue2 = queue1.fork();
      var queue3 = queue1.fork();
      var queue4 = queue1.fork();
      var queue5 = queue1.fork();

      for (var i = 0; i < 4; i++) {
        var queue1Fired = false;
        var queue2Fired = false;
        var queue3Fired = false;
        var queue4Fired = false;
        var queue5Fired = false;

        queue5.next.then(expectAsync((_) {
          queue5Fired = true;
          expect(queue1Fired, isTrue);
          expect(queue2Fired, isTrue);
          expect(queue3Fired, isTrue);
          expect(queue4Fired, isTrue);
        }));

        queue1.next.then(expectAsync((_) {
          queue1Fired = true;
          expect(queue2Fired, isFalse);
          expect(queue3Fired, isFalse);
          expect(queue4Fired, isFalse);
          expect(queue5Fired, isFalse);
        }));

        queue4.next.then(expectAsync((_) {
          queue4Fired = true;
          expect(queue1Fired, isTrue);
          expect(queue2Fired, isTrue);
          expect(queue3Fired, isTrue);
          expect(queue5Fired, isFalse);
        }));

        queue2.next.then(expectAsync((_) {
          queue2Fired = true;
          expect(queue1Fired, isTrue);
          expect(queue3Fired, isFalse);
          expect(queue4Fired, isFalse);
          expect(queue5Fired, isFalse);
        }));

        queue3.next.then(expectAsync((_) {
          queue3Fired = true;
          expect(queue1Fired, isTrue);
          expect(queue2Fired, isTrue);
          expect(queue4Fired, isFalse);
          expect(queue5Fired, isFalse);
        }));
      }
    });

    test("forks can be created from forks", () async {
      var queue1 = new StreamQueue<int>(createStream());

      var queue2 = queue1.fork();
      expect(await queue1.next, 1);
      expect(await queue2.next, 1);

      var queue3 = queue2.fork();
      expect(await queue1.next, 2);
      expect(await queue2.next, 2);
      expect(await queue3.next, 2);

      var queue4 = queue3.fork();
      expect(await queue1.next, 3);
      expect(await queue2.next, 3);
      expect(await queue3.next, 3);
      expect(await queue4.next, 3);

      var queue5 = queue4.fork();
      expect(await queue1.next, 4);
      expect(await queue2.next, 4);
      expect(await queue3.next, 4);
      expect(await queue4.next, 4);
      expect(await queue5.next, 4);

      var queue6 = queue5.fork();
      expect(await queue1.hasNext, isFalse);
      expect(await queue2.hasNext, isFalse);
      expect(await queue3.hasNext, isFalse);
      expect(await queue4.hasNext, isFalse);
      expect(await queue5.hasNext, isFalse);
      expect(await queue6.hasNext, isFalse);
    });

    group("canceling:", () {
      test("cancelling a fork doesn't cancel its source", () async {
        var queue1 = new StreamQueue<int>(createStream());
        var queue2 = queue1.fork();

        queue2.cancel();
        expect(() => queue2.next, throwsStateError);

        expect(await queue1.next, 1);
        expect(await queue1.next, 2);
        expect(await queue1.next, 3);
        expect(await queue1.next, 4);
        expect(await queue1.hasNext, isFalse);
      });

      test("cancelling a source doesn't cancel its unmaterialized fork",
          () async {
        var queue1 = new StreamQueue<int>(createStream());
        var queue2 = queue1.fork();

        queue1.cancel();
        expect(() => queue1.next, throwsStateError);

        expect(await queue2.next, 1);
        expect(await queue2.next, 2);
        expect(await queue2.next, 3);
        expect(await queue2.next, 4);
        expect(await queue2.hasNext, isFalse);
      });

      test("cancelling a source doesn't cancel its materialized fork",
          () async {
        var queue1 = new StreamQueue<int>(createStream());
        var queue2 = queue1.fork();

        expect(await queue1.next, 1);

        queue1.cancel();
        expect(() => queue1.next, throwsStateError);

        expect(await queue2.next, 1);
        expect(await queue2.next, 2);
        expect(await queue2.next, 3);
        expect(await queue2.next, 4);
        expect(await queue2.hasNext, isFalse);
      });

      test("the underlying stream is only canceled once all forks are canceled",
          () async {
        var controller = new StreamController();
        var queue1 = new StreamQueue<int>(controller.stream);
        var queue2 = queue1.fork();

        await flushMicrotasks();
        expect(controller.hasListener, isFalse);

        expect(queue1.next, completion(1));
        await flushMicrotasks();
        expect(controller.hasListener, isTrue);

        queue2.cancel();
        await flushMicrotasks();
        expect(controller.hasListener, isTrue);

        controller.add(1);
        queue1.cancel();
        await flushMicrotasks();
        expect(controller.hasListener, isFalse);
      });

      group("with immediate,", () {
        test("cancelling a fork doesn't cancel its source", () async {
          var queue1 = new StreamQueue<int>(createStream());
          var queue2 = queue1.fork();

          queue2.cancel(immediate: true);
          expect(() => queue2.next, throwsStateError);

          expect(await queue1.next, 1);
          expect(await queue1.next, 2);
          expect(await queue1.next, 3);
          expect(await queue1.next, 4);
          expect(await queue1.hasNext, isFalse);
        });

        test("cancelling a source doesn't cancel its unmaterialized fork",
            () async {
          var queue1 = new StreamQueue<int>(createStream());
          var queue2 = queue1.fork();

          queue1.cancel(immediate: true);
          expect(() => queue1.next, throwsStateError);

          expect(await queue2.next, 1);
          expect(await queue2.next, 2);
          expect(await queue2.next, 3);
          expect(await queue2.next, 4);
          expect(await queue2.hasNext, isFalse);
        });

        test("cancelling a source doesn't cancel its materialized fork",
            () async {
          var queue1 = new StreamQueue<int>(createStream());
          var queue2 = queue1.fork();

          expect(await queue1.next, 1);

          queue1.cancel(immediate: true);
          expect(() => queue1.next, throwsStateError);

          expect(await queue2.next, 1);
          expect(await queue2.next, 2);
          expect(await queue2.next, 3);
          expect(await queue2.next, 4);
          expect(await queue2.hasNext, isFalse);
        });

        test("the underlying stream is only canceled once all forks are "
            "canceled", () async {
          var controller = new StreamController();
          var queue1 = new StreamQueue<int>(controller.stream);
          var queue2 = queue1.fork();

          await flushMicrotasks();
          expect(controller.hasListener, isFalse);

          expect(queue1.next, throwsStateError);
          await flushMicrotasks();
          expect(controller.hasListener, isTrue);

          queue2.cancel(immediate: true);
          await flushMicrotasks();
          expect(controller.hasListener, isTrue);

          queue1.cancel(immediate: true);
          await flushMicrotasks();
          expect(controller.hasListener, isFalse);
        });
      });
    });

    group("pausing:", () {
      test("the underlying stream is only implicitly paused when no forks are "
          "awaiting input", () async {
        var controller = new StreamController();
        var queue1 = new StreamQueue<int>(controller.stream);
        var queue2 = queue1.fork();

        controller.add(1);
        expect(await queue1.next, 1);
        expect(controller.hasListener, isTrue);
        expect(controller.isPaused, isTrue);

        expect(queue1.next, completion(2));
        await flushMicrotasks();
        expect(controller.isPaused, isFalse);

        controller.add(2);
        await flushMicrotasks();
        expect(controller.isPaused, isTrue);

        expect(queue2.next, completion(1));
        expect(queue2.next, completion(2));
        expect(queue2.next, completion(3));
        await flushMicrotasks();
        expect(controller.isPaused, isFalse);

        controller.add(3);
        await flushMicrotasks();
        expect(controller.isPaused, isTrue);
      });

      test("pausing a fork doesn't pause its source", () async {
        var queue1 = new StreamQueue<int>(createStream());
        var queue2 = queue1.fork();

        queue2.rest.listen(expectAsync((_) {}, count: 0)).pause();

        expect(await queue1.next, 1);
        expect(await queue1.next, 2);
        expect(await queue1.next, 3);
        expect(await queue1.next, 4);
        expect(await queue1.hasNext, isFalse);
      });

      test("pausing a source doesn't pause its fork", () async {
        var queue1 = new StreamQueue<int>(createStream());
        var queue2 = queue1.fork();

        queue1.rest.listen(expectAsync((_) {}, count: 0)).pause();

        expect(await queue2.next, 1);
        expect(await queue2.next, 2);
        expect(await queue2.next, 3);
        expect(await queue2.next, 4);
        expect(await queue2.hasNext, isFalse);
      });

      test("the underlying stream is only paused when all forks are paused",
          () async {
        var controller = new StreamController();
        var queue1 = new StreamQueue<int>(controller.stream);
        var queue2 = queue1.fork();

        await flushMicrotasks();
        expect(controller.hasListener, isFalse);

        var sub1 = queue1.rest.listen(null);
        await flushMicrotasks();
        expect(controller.hasListener, isTrue);
        expect(controller.isPaused, isFalse);

        sub1.pause();
        await flushMicrotasks();
        expect(controller.isPaused, isTrue);

        expect(queue2.next, completion(1));
        await flushMicrotasks();
        expect(controller.isPaused, isFalse);

        controller.add(1);
        await flushMicrotasks();
        expect(controller.isPaused, isTrue);

        var sub2 = queue2.rest.listen(null);
        await flushMicrotasks();
        expect(controller.isPaused, isFalse);

        sub2.pause();
        await flushMicrotasks();
        expect(controller.isPaused, isTrue);

        sub1.resume();
        await flushMicrotasks();
        expect(controller.isPaused, isFalse);
      });
    });
  });

  test("all combinations sequential skip/next/take operations", () async {
    // Takes all combinations of two of next, skip and take, then ends with
    // doing rest. Each of the first rounds do 10 events of each type,
    // the rest does 20 elements.
    var eventCount = 20 * (3 * 3 + 1);
    var events = new StreamQueue<int>(createLongStream(eventCount));

    // Test expecting [startIndex .. startIndex + 9] as events using
    // `next`.
    nextTest(startIndex) {
      for (int i = 0; i < 10; i++) {
        expect(events.next, completion(startIndex + i));
      }
    }

    // Test expecting 10 events to be skipped.
    skipTest(startIndex) {
      expect(events.skip(10), completion(0));
    }

    // Test expecting [startIndex .. startIndex + 9] as events using
    // `take(10)`.
    takeTest(startIndex) {
      expect(events.take(10),
             completion(new List.generate(10, (i) => startIndex + i)));
    }
    var tests = [nextTest, skipTest, takeTest];

    int counter = 0;
    // Run through all pairs of two tests and run them.
    for (int i = 0; i < tests.length; i++) {
      for (int j = 0; j < tests.length; j++) {
        tests[i](counter);
        tests[j](counter + 10);
        counter += 20;
      }
    }
    // Then expect 20 more events as a `rest` call.
    expect(events.rest.toList(),
           completion(new List.generate(20, (i) => counter + i)));
  });
}

Stream<int> createStream() async* {
  yield 1;
  await flushMicrotasks();
  yield 2;
  await flushMicrotasks();
  yield 3;
  await flushMicrotasks();
  yield 4;
}

Stream<int> createErrorStream() {
  StreamController controller = new StreamController<int>();
  () async {
    controller.add(1);
    await flushMicrotasks();
    controller.add(2);
    await flushMicrotasks();
    controller.addError("To err is divine!");
    await flushMicrotasks();
    controller.add(4);
    await flushMicrotasks();
    controller.close();
  }();
  return controller.stream;
}

Stream<int> createLongStream(int eventCount) async* {
  for (int i = 0; i < eventCount; i++) yield i;
}

Future flushMicrotasks() => new Future.delayed(Duration.ZERO);
