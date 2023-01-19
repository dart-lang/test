// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:checks/context.dart';

extension FutureChecks<T> on Check<Future<T>> {
  /// Expects that the `Future` completes to a value without throwing.
  ///
  /// Returns a future that completes to a [Check<T>] on the result once the
  /// future completes.
  ///
  /// Fails if the future completes as an error.
  Future<Check<T>> completes() async {
    return await context.nestAsync<T>('Completes to', (actual) async {
      try {
        return Extracted.value(await actual);
      } catch (e) {
        return Extracted.rejection(
            actual: ['A future that completes as an error'],
            which: prefixFirst('Threw ', literal(e)));
      }
    });
  }

  /// Expectst that the `Future` never completes as a value or an error.
  ///
  /// Immediately returns and does not cause the test to remain running if it
  /// ends.
  /// If the future completes at any time, raises a test failure. This may
  /// happen after the test has already appeared to succeed.
  ///
  /// Not compatible with [softCheck] or [softCheckAsync] since there is no
  /// concrete end point where this condition has definitely succeeded.
  void doesNotComplete() {
    context.expectUnawaited(() => ['does not complete as value or error'],
        (actual, reject) {
      unawaited(actual.then((r) {
        reject(Rejection(
            actual: prefixFirst('A future that completed to ', literal(r))));
      }, onError: (e, st) {
        reject(Rejection(actual: [
          'A future that completed as an error:'
        ], which: [
          ...prefixFirst('threw ', literal(e)),
          ...(const LineSplitter()).convert(st.toString())
        ]));
      }));
    });
  }

  /// Expects that the `Future` completes as an error.
  ///
  /// Returns a future that completes to a [Check<E>] on the error once the
  /// future completes as an error.
  ///
  /// Fails if the future completes to a value.
  Future<Check<E>> throws<E>() async {
    return await context.nestAsync<E>('Completes as an error of type $E',
        (actual) async {
      try {
        return Extracted.rejection(
            actual: prefixFirst('Completed to ', literal(await actual)),
            which: ['Did not throw']);
      } catch (e) {
        if (e is E) return Extracted.value(e as E);
        return Extracted.rejection(
            actual: prefixFirst('Completed to error ', literal(e)),
            which: ['Is not an $E']);
      }
    });
  }
}

/// Expectations on a [StreamQueue].
///
/// Streams should be wrapped in user test code so that any reuse of the same
/// Stream, and the full stream lifecycle, is explicit.
extension StreamChecks<T> on Check<StreamQueue<T>> {
  /// Expect that the `Stream` emits a value without first emitting an error.
  ///
  /// Returns a `Future` that completes to a [Check<T>] on the next event
  /// emitted by the stream.
  ///
  /// Fails if the stream emits an error instead of a value, or closes without
  /// emitting a value.
  Future<Check<T>> emits() async {
    return await context.nestAsync<T>('Emits a value', (actual) async {
      if (!await actual.hasNext) {
        return Extracted.rejection(
            actual: ['an empty stream'], which: ['did not emit any value']);
      }
      try {
        return Extracted.value(await actual.next);
      } catch (e) {
        return Extracted.rejection(
            actual: prefixFirst('A stream with error ', literal(e)),
            which: ['emitted an error instead of a value']);
      }
    });
  }

  /// Expects that the `Stream` emits any number of events before emitting an
  /// event that satisfies [condition].
  ///
  /// Returns a `Future` that completes after the stream has emitted an event
  /// that satisfies [condition].
  ///
  /// Fails if the stream emits an error or closes before emitting a matching
  /// event.
  Future<void> emitsThrough(Condition<T> condition) async {
    await context.expectAsync(
        () => [
              'Emits any values then a value that:',
              ...indent(describe(condition))
            ], (actual) async {
      var count = 0;
      await for (var emitted in actual.rest) {
        if (softCheck(emitted, condition) == null) {
          return null;
        }
        count++;
      }
      return Rejection(
          actual: ['a stream'],
          which: ['ended after emitting $count elements with none matching']);
    });
  }

  /// Expects that the `Stream` closes without emitting any even that satisfies
  /// [condition].
  ///
  /// Returns a `Future` that completes after the stream has closed.
  ///
  /// Fails if the stream emits any even that satisfies [condition].
  Future<void> neverEmits(Condition<T> condition) async {
    await context.expectAsync(
        () => ['Never emits a value that:', ...indent(describe(condition))],
        (actual) async {
      var count = 0;
      await for (var emitted in actual.rest) {
        if (softCheck(emitted, condition) == null) {
          return Rejection(actual: [
            'a stream'
          ], which: [
            ...prefixFirst('emitted ', literal(emitted)),
            if (count > 0) 'following $count other items'
          ]);
        }
        count++;
      }
      return null;
    });
  }
}

extension ChainAsync<T> on Future<Check<T>> {
  /// Checks the expectations in [condition] against the result of this
  /// `Future`.
  ///
  /// Extensions written on [Check] cannot be invoked on [Future<Check>]. This
  /// method allows adding expectations for the value without awaiting it.
  ///
  /// ```dart
  /// await checkThat(someFuture).completes().that((r) => r.equals('expected'));
  /// // or, with the intermediate `await`:
  /// (await checkThat(someFuture).completes()).equals('expected');
  /// ```
  Future<void> that(Condition<T> condition) async {
    await condition.applyAsync(await this);
  }
}
