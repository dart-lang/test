// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:test/src/util/cancelable_future.dart';
import 'package:test/test.dart';

void main() {
  group("without being canceled", () {
    var completer;
    setUp(() {
      completer = new CancelableCompleter(expectAsync(() {}, count: 0));
    });

    test("sends values to the future", () {
      expect(completer.future, completion(equals(1)));
      expect(completer.isCompleted, isFalse);
      completer.complete(1);
      expect(completer.isCompleted, isTrue);
    });

    test("sends errors to the future", () {
      expect(completer.future, throwsA("error"));
      expect(completer.isCompleted, isFalse);
      completer.completeError("error");
      expect(completer.isCompleted, isTrue);
    });

    test("sends values in a future to the future", () {
      expect(completer.future, completion(equals(1)));
      expect(completer.isCompleted, isFalse);
      completer.complete(new Future.value(1));
      expect(completer.isCompleted, isTrue);
    });

    test("sends errors in a future to the future", () {
      expect(completer.future, throwsA("error"));
      expect(completer.isCompleted, isFalse);
      completer.complete(new Future.error("error"));
      expect(completer.isCompleted, isTrue);
    });

    group("throws a StateError if completed", () {
      test("successfully twice", () {
        completer.complete(1);
        expect(() => completer.complete(1), throwsStateError);
      });

      test("successfully then unsuccessfully", () {
        completer.complete(1);
        expect(() => completer.completeError("error"), throwsStateError);
      });

      test("unsuccessfully twice", () {
        expect(completer.future, throwsA("error"));
        completer.completeError("error");
        expect(() => completer.completeError("error"), throwsStateError);
      });

      test("successfully then with a future", () {
        completer.complete(1);
        expect(() => completer.complete(new Completer().future),
            throwsStateError);
      });

      test("with a future then successfully", () {
        completer.complete(new Completer().future);
        expect(() => completer.complete(1), throwsStateError);
      });

      test("with a future twice", () {
        completer.complete(new Completer().future);
        expect(() => completer.complete(new Completer().future),
            throwsStateError);
      });
    });

    group("CancelableFuture.fromFuture", () {
      test("forwards values", () {
        expect(new CancelableFuture.fromFuture(new Future.value(1)),
            completion(equals(1)));
      });

      test("forwards errors", () {
        expect(new CancelableFuture.fromFuture(new Future.error("error")),
            throwsA("error"));
      });
    });
  });

  group("when canceled", () {
    test("causes the future never to fire", () async {
      var completer = new CancelableCompleter();
      completer.future.whenComplete(expectAsync(() {}, count: 0));
      completer.future.cancel();

      // Give the future plenty of time to fire if it's going to.
      await flushMicrotasks();
      completer.complete();
      await flushMicrotasks();
    });

    test("fires onCancel", () {
      var canceled = false;
      var completer;
      completer = new CancelableCompleter(expectAsync(() {
        expect(completer.isCanceled, isTrue);
        canceled = true;
      }));

      expect(canceled, isFalse);
      expect(completer.isCanceled, isFalse);
      expect(completer.isCompleted, isFalse);
      completer.future.cancel();
      expect(canceled, isTrue);
      expect(completer.isCanceled, isTrue);
      expect(completer.isCompleted, isFalse);
    });

    test("returns the onCancel future each time cancel is called", () {
      var completer = new CancelableCompleter(expectAsync(() {
        return new Future.value(1);
      }));
      expect(completer.future.cancel(), completion(equals(1)));
      expect(completer.future.cancel(), completion(equals(1)));
      expect(completer.future.cancel(), completion(equals(1)));
    });

    test("returns a future even if onCancel doesn't", () {
      var completer = new CancelableCompleter(expectAsync(() {}));
      expect(completer.future.cancel(), completes);
    });

    test("doesn't call onCancel if the completer has completed", () {
      var completer = new CancelableCompleter(expectAsync(() {}, count: 0));
      completer.complete(1);
      completer.future.whenComplete(expectAsync(() {}, count: 0));
      expect(completer.future.cancel(), completes);
    });

    test("does call onCancel if the completer has completed to an unfired "
        "Future", () {
      var completer = new CancelableCompleter(expectAsync(() {}));
      completer.complete(new Completer().future);
      expect(completer.future.cancel(), completes);
    });

    test("doesn't call onCancel if the completer has completed to a fired "
        "Future", () async {
      var completer = new CancelableCompleter(expectAsync(() {}, count: 0));
      completer.complete(new Future.value(1));
      await completer.future;
      expect(completer.future.cancel(), completes);
    });

    test("can be completed once after being canceled", () async {
      var completer = new CancelableCompleter();
      completer.future.whenComplete(expectAsync(() {}, count: 0));
      await completer.future.cancel();
      completer.complete(1);
      expect(() => completer.complete(1), throwsStateError);
    });

    test("throws a CancelException along non-canceled branches", () {
      var completer = new CancelableCompleter();
      expect(completer.future.then((_) {}), throwsCancelException);
      completer.future.then((_) {}).cancel();
    });

    test("doesn't throw a CancelException further along the canceled chain",
        () async {
      var completer = new CancelableCompleter();
      completer.future.then((_) {}).whenComplete(expectAsync((_) {}, count: 0));
      completer.future.cancel();
      await flushMicrotasks();
    });
  });

  group("asStream()", () {
    test("emits a value and then closes", () {
      var completer = new CancelableCompleter();
      expect(completer.future.asStream().toList(), completion(equals([1])));
      completer.complete(1);
    });

    test("emits an error and then closes", () {
      var completer = new CancelableCompleter();
      var queue = new StreamQueue(completer.future.asStream());
      expect(queue.next, throwsA("error"));
      expect(queue.hasNext, completion(isFalse));
      completer.completeError("error");
    });

    test("cancels the completer when the subscription is canceled", () {
      var completer = new CancelableCompleter(expectAsync(() {}));
      var sub = completer.future.asStream()
          .listen(expectAsync((_) {}, count: 0));
      expect(completer.future, throwsCancelException);
      sub.cancel();
      expect(completer.isCanceled, isTrue);
    });
  });

  group("timeout()", () {
    test("emits a value if one arrives before timeout", () {
      var completer = new CancelableCompleter();
      expect(
          completer.future.timeout(
              new Duration(hours: 1),
              onTimeout: expectAsync(() {}, count: 0)),
          completion(equals(1)));
      completer.complete(1);
    });

    test("emits an error if one arrives before timeout", () {
      var completer = new CancelableCompleter();
      expect(
          completer.future.timeout(
              new Duration(hours: 1),
              onTimeout: expectAsync(() {}, count: 0)),
          throwsA("error"));
      completer.completeError("error");
    });

    test("cancels the completer when the future times out", () async {
      var completer = new CancelableCompleter(expectAsync(() {}));
      expect(completer.future.timeout(Duration.ZERO),
          throwsA(new isInstanceOf<TimeoutException>()));
      expect(completer.future, throwsCancelException);
      await flushMicrotasks();
      expect(completer.isCanceled, isTrue);
    });

    test("runs the user's onTimeout function when the future times out",
        () async {
      var completer = new CancelableCompleter(expectAsync(() {}));
      expect(
          completer.future.timeout(
              Duration.ZERO,
              onTimeout: expectAsync(() => 1)),
          completion(equals(1)));
      expect(completer.future, throwsCancelException);
      await flushMicrotasks();
      expect(completer.isCanceled, isTrue);
    });
  });
}

const Matcher throwsCancelException =
    const Throws(const isInstanceOf<CancelException>());

Future flushMicrotasks() => new Future.delayed(Duration.ZERO);
