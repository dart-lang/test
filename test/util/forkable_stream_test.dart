// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): Get rid of this when https://codereview.chromium.org/1241723003/
// lands.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test/src/util/forkable_stream.dart';
import 'package:test/src/util/stream_queue.dart';

void main() {
  var controller;
  var stream;
  setUp(() {
    var cancelFuture = new Future.value(42);
    controller = new StreamController<int>(onCancel: () => cancelFuture);
    stream = new ForkableStream<int>(controller.stream);
  });

  group("with no forks", () {
    test("forwards events, errors, and close", () async {
      var queue = new StreamQueue(stream);

      controller.add(1);
      expect(await queue.next, equals(1));

      controller.add(2);
      expect(await queue.next, equals(2));

      controller.addError("error");
      expect(queue.next, throwsA("error"));
      await flushMicrotasks();

      controller.add(3);
      expect(await queue.next, equals(3));

      controller.close();
      expect(await queue.hasNext, isFalse);
    });

    test("listens to, pauses, and cancels the controller", () {
      expect(controller.hasListener, isFalse);

      var sub = stream.listen(null);
      expect(controller.hasListener, isTrue);

      sub.pause();
      expect(controller.isPaused, isTrue);

      sub.resume();
      expect(controller.isPaused, isFalse);

      sub.cancel();
      expect(controller.hasListener, isFalse);
    });

    test("unpauses the controller when a fork is listened", () {
      stream.listen(null).pause();
      expect(controller.isPaused, isTrue);

      var fork = stream.fork();
      expect(controller.isPaused, isTrue);

      fork.listen(null);
      expect(controller.isPaused, isFalse);
    });
  });

  group("with a fork created before the stream was listened", () {
    var fork;
    setUp(() {
      fork = stream.fork();
    });

    test("forwards events, errors, and close to both branches", () async {
      var queue = new StreamQueue(stream);
      var forkQueue = new StreamQueue(fork);

      controller.add(1);
      expect(await queue.next, equals(1));
      expect(await forkQueue.next, equals(1));

      controller.add(2);
      expect(await queue.next, equals(2));
      expect(await forkQueue.next, equals(2));

      controller.addError("error");
      expect(queue.next, throwsA("error"));
      expect(forkQueue.next, throwsA("error"));
      await flushMicrotasks();

      controller.add(3);
      expect(await queue.next, equals(3));
      expect(await forkQueue.next, equals(3));

      controller.close();
      expect(await queue.hasNext, isFalse);
      expect(await forkQueue.hasNext, isFalse);
    });

    test('listens to the source when the original is listened', () {
      expect(controller.hasListener, isFalse);
      stream.listen(null);
      expect(controller.hasListener, isTrue);
    });

    test('listens to the source when the fork is listened', () {
      expect(controller.hasListener, isFalse);
      fork.listen(null);
      expect(controller.hasListener, isTrue);
    });
  });

  test(
      "with a fork created after the stream emitted a few events, forwards "
      "future events, errors, and close to both branches", () async {
    var queue = new StreamQueue(stream);

    controller.add(1);
    expect(await queue.next, equals(1));

    controller.add(2);
    expect(await queue.next, equals(2));

    var fork = stream.fork();
    var forkQueue = new StreamQueue(fork);

    controller.add(3);
    expect(await queue.next, equals(3));
    expect(await forkQueue.next, equals(3));

    controller.addError("error");
    expect(queue.next, throwsA("error"));
    expect(forkQueue.next, throwsA("error"));
    await flushMicrotasks();

    controller.close();
    expect(await queue.hasNext, isFalse);
    expect(await forkQueue.hasNext, isFalse);
  });

  group("with multiple forks", () {
    var fork1;
    var fork2;
    var fork3;
    var fork4;
    setUp(() {
      fork1 = stream.fork();
      fork2 = stream.fork();
      fork3 = stream.fork();
      fork4 = stream.fork();
    });

    test("forwards events, errors, and close to all branches", () async {
      var queue1 = new StreamQueue(stream);
      var queue2 = new StreamQueue(fork1);
      var queue3 = new StreamQueue(fork2);
      var queue4 = new StreamQueue(fork3);
      var queue5 = new StreamQueue(fork4);

      controller.add(1);
      expect(await queue1.next, equals(1));
      expect(await queue2.next, equals(1));
      expect(await queue3.next, equals(1));
      expect(await queue4.next, equals(1));
      expect(await queue5.next, equals(1));

      controller.add(2);
      expect(await queue1.next, equals(2));
      expect(await queue2.next, equals(2));
      expect(await queue3.next, equals(2));
      expect(await queue4.next, equals(2));
      expect(await queue5.next, equals(2));

      controller.addError("error");
      expect(queue1.next, throwsA("error"));
      expect(queue2.next, throwsA("error"));
      expect(queue3.next, throwsA("error"));
      expect(queue4.next, throwsA("error"));
      expect(queue5.next, throwsA("error"));
      await flushMicrotasks();

      controller.add(3);
      expect(await queue1.next, equals(3));
      expect(await queue2.next, equals(3));
      expect(await queue3.next, equals(3));
      expect(await queue4.next, equals(3));
      expect(await queue5.next, equals(3));

      controller.close();
      expect(await queue1.hasNext, isFalse);
      expect(await queue2.hasNext, isFalse);
      expect(await queue3.hasNext, isFalse);
      expect(await queue4.hasNext, isFalse);
      expect(await queue5.hasNext, isFalse);
    });

    test("forwards events in order of forking", () async {
      var queue1 = new StreamQueue(stream);
      var queue2 = new StreamQueue(fork1);
      var queue3 = new StreamQueue(fork2);
      var queue4 = new StreamQueue(fork3);
      var queue5 = new StreamQueue(fork4);

      for (var i = 0; i < 4; i++) {
        controller.add(i);

        var queue1Fired = false;
        var queue2Fired = false;
        var queue3Fired = false;
        var queue4Fired = false;
        var queue5Fired = false;

        queue5.next.then(expectAsync1((_) {
          queue5Fired = true;
          expect(queue1Fired, isTrue);
          expect(queue2Fired, isTrue);
          expect(queue3Fired, isTrue);
          expect(queue4Fired, isTrue);
        }));

        queue1.next.then(expectAsync1((_) {
          queue1Fired = true;
          expect(queue2Fired, isFalse);
          expect(queue3Fired, isFalse);
          expect(queue4Fired, isFalse);
          expect(queue5Fired, isFalse);
        }));

        queue4.next.then(expectAsync1((_) {
          queue4Fired = true;
          expect(queue1Fired, isTrue);
          expect(queue2Fired, isTrue);
          expect(queue3Fired, isTrue);
          expect(queue5Fired, isFalse);
        }));

        queue2.next.then(expectAsync1((_) {
          queue2Fired = true;
          expect(queue1Fired, isTrue);
          expect(queue3Fired, isFalse);
          expect(queue4Fired, isFalse);
          expect(queue5Fired, isFalse);
        }));

        queue3.next.then(expectAsync1((_) {
          queue3Fired = true;
          expect(queue1Fired, isTrue);
          expect(queue2Fired, isTrue);
          expect(queue4Fired, isFalse);
          expect(queue5Fired, isFalse);
        }));
      }
    });

    test("pauses the source when all forks are paused and/or not listening",
        () {
      var sub1 = stream.listen(null);
      var sub2 = fork1.listen(null);
      expect(controller.isPaused, isFalse);

      sub1.pause();
      expect(controller.isPaused, isFalse);

      sub2.pause();
      expect(controller.isPaused, isTrue);

      var sub3 = fork2.listen(null);
      expect(controller.isPaused, isFalse);

      sub3.pause();
      expect(controller.isPaused, isTrue);

      sub2.resume();
      expect(controller.isPaused, isFalse);

      sub2.cancel();
      expect(controller.isPaused, isTrue);
    });

    test("cancels the source when all forks are canceled", () async {
      var sub1 = stream.listen(null);
      expect(controller.hasListener, isTrue);

      var sub2 = fork1.listen(null);
      expect(controller.hasListener, isTrue);

      expect(sub1.cancel(), completion(isNull));
      await flushMicrotasks();
      expect(controller.hasListener, isTrue);

      expect(sub2.cancel(), completion(isNull));
      await flushMicrotasks();
      expect(controller.hasListener, isTrue);

      expect(fork2.listen(null).cancel(), completion(isNull));
      await flushMicrotasks();
      expect(controller.hasListener, isTrue);

      expect(fork3.listen(null).cancel(), completion(isNull));
      await flushMicrotasks();
      expect(controller.hasListener, isTrue);

      expect(fork4.listen(null).cancel(), completion(equals(42)));
      await flushMicrotasks();
      expect(controller.hasListener, isFalse);
    });
  });

  group("modification during dispatch:", () {
    test("forking during onCancel", () {
      controller = new StreamController<int>(onCancel: expectAsync0(() {
        expect(stream.fork().toList(), completion(isEmpty));
      }));
      stream = new ForkableStream<int>(controller.stream);

      stream.listen(null).cancel();
    });

    test("forking during onPause", () {
      controller = new StreamController<int>(onPause: expectAsync0(() {
        stream.fork().listen(null);
      }));
      stream = new ForkableStream<int>(controller.stream);

      stream.listen(null).pause();

      // The fork created in onPause should have resumed the stream.
      expect(controller.isPaused, isFalse);
    });

    test("forking during onData", () {
      var sub;
      sub = stream.listen(expectAsync1((value1) {
        expect(value1, equals(1));
        stream.fork().listen(expectAsync1((value2) {
          expect(value2, equals(2));
        }));
        sub.cancel();
      }));

      controller.add(1);
      controller.add(2);
    });

    test("canceling a fork during onData", () {
      var fork = stream.fork();
      var forkSub = fork.listen(expectAsync1((_) {}, count: 0));

      stream.listen(expectAsync1((_) => forkSub.cancel()));
      controller.add(null);
    });

    test("forking during onError", () {
      var sub;
      sub = stream.listen(null, onError: expectAsync1((error1) {
        expect(error1, equals("error 1"));
        stream.fork().listen(null, onError: expectAsync1((error2) {
          expect(error2, equals("error 2"));
        }));
        sub.cancel();
      }));

      controller.addError("error 1");
      controller.addError("error 2");
    });

    test("canceling a fork during onError", () {
      var fork = stream.fork();
      var forkSub = fork.listen(expectAsync1((_) {}, count: 0));

      stream.listen(null, onError: expectAsync1((_) => forkSub.cancel()));
      controller.addError("error");
    });

    test("forking during onDone", () {
      stream.listen(null, onDone: expectAsync0(() {
        expect(stream.fork().toList(), completion(isEmpty));
      }));

      controller.close();
    });

    test("canceling a fork during onDone", () {
      var fork = stream.fork();
      var forkSub = fork.listen(null, onDone: expectAsync0(() {}, count: 0));

      stream.listen(null, onDone: expectAsync0(() => forkSub.cancel()));
      controller.close();
    });
  });

  group("throws an error when", () {
    test("a cancelled stream is forked", () {
      stream.listen(null).cancel();
      expect(stream.fork().toList(), completion(isEmpty));
    });

    test("a cancelled stream is forked even when other forks are alive", () {
      stream.fork().listen(null);
      stream.listen(null).cancel();

      expect(controller.hasListener, isTrue);
      expect(stream.fork().toList(), completion(isEmpty));
    });

    test("a closed stream is forked", () async {
      controller.close();
      await stream.listen(null).asFuture();
      expect(stream.fork().toList(), completion(isEmpty));
    });
  });
}

Future flushMicrotasks() => new Future.delayed(Duration.ZERO);
