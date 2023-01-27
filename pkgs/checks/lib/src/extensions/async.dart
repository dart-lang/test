// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:checks/context.dart';

extension FutureChecks<T> on Subject<Future<T>> {
  /// Expects that the `Future` completes to a value without throwing.
  ///
  /// Returns a future that completes to a [Subject] on the result once the
  /// future completes.
  ///
  /// Fails if the future completes as an error.
  Future<Subject<T>> completes() =>
      context.nestAsync<T>('completes to a value', (actual) async {
        try {
          return Extracted.value(await actual);
        } catch (e) {
          return Extracted.rejection(
              actual: ['a future that completes as an error'],
              which: prefixFirst('threw ', literal(e)));
        }
      });

  /// Expects that the `Future` never completes as a value or an error.
  ///
  /// Immediately returns and does not cause the test to remain running if it
  /// ends.
  /// If the future completes at any time, raises a test failure. This may
  /// happen after the test has already appeared to succeed.
  ///
  /// Not compatible with [softCheck] or [softCheckAsync] since there is no
  /// concrete end point where this condition has definitely succeeded.
  void doesNotComplete() {
    context.expectUnawaited(() => ['does not complete'], (actual, reject) {
      unawaited(actual.then((r) {
        reject(Rejection(
            actual: prefixFirst('a future that completed to ', literal(r))));
      }, onError: (e, st) {
        reject(Rejection(actual: [
          'a future that completed as an error:'
        ], which: [
          ...prefixFirst('threw ', literal(e)),
          ...(const LineSplitter()).convert(st.toString())
        ]));
      }));
    });
  }

  /// Expects that the `Future` completes as an error.
  ///
  /// Returns a future that completes to a [Subject] on the error once the
  /// future completes as an error.
  ///
  /// Fails if the future completes to a value.
  Future<Subject<E>> throws<E extends Object>() => context.nestAsync<E>(
          'completes to an error${E == Object ? '' : ' of type $E'}',
          (actual) async {
        try {
          return Extracted.rejection(
              actual: prefixFirst('completed to ', literal(await actual)),
              which: ['did not throw']);
        } on E catch (e) {
          return Extracted.value(e);
        } catch (e) {
          return Extracted.rejection(
              actual: prefixFirst('completed to error ', literal(e)),
              which: ['is not an $E']);
        }
      });
}

/// Expectations on a [StreamQueue].
///
/// Streams should be wrapped in user test code so that any reuse of the same
/// Stream, and the full stream lifecycle, is explicit.
extension StreamChecks<T> on Subject<StreamQueue<T>> {
  /// Calls [Context.expectAsync] and wraps [predicate] with a transaction.
  ///
  /// The transaction is committed if the check passes, or rejected if it fails.
  Future<void> _expectAsync(Iterable<String> Function() clause,
          FutureOr<Rejection?> Function(StreamQueue<T>) predicate) =>
      context.expectAsync(clause, (actual) async {
        final transaction = actual.startTransaction();
        final copy = transaction.newQueue();
        final result = await predicate(copy);
        if (result == null) {
          transaction.commit(copy);
        } else {
          transaction.reject();
        }
        return result;
      });

  /// Expect that the `Stream` emits a value without first emitting an error.
  ///
  /// Returns a `Future` that completes to a [Subject] on the next event emitted
  /// by the stream.
  ///
  /// Fails if the stream emits an error instead of a value, or closes without
  /// emitting a value.
  Future<Subject<T>> emits() =>
      context.nestAsync<T>('emits a value', (actual) async {
        if (!await actual.hasNext) {
          return Extracted.rejection(
              actual: ['a stream'],
              which: ['closed without emitting enough values']);
        }
        try {
          await actual.peek;
          return Extracted.value(await actual.next);
        } catch (e) {
          return Extracted.rejection(
              actual: prefixFirst('a stream with error ', literal(e)),
              which: ['emitted an error instead of a value']);
        }
      });

  /// Expects that the stream emits an error of type [E].
  ///
  /// Returns a [Subject] on the error's value.
  ///
  /// Fails if the stream emits any value.
  /// Fails if the stream emits an error with an incorrect type.
  /// Fails if the stream closes without emitting an error.
  ///
  /// If this expectation fails, the source queue will be left in it's original
  /// state.
  /// If this expectation succeeds, consumes the error event.
  Future<Subject<E>> emitsError<E extends Object>() =>
      context.nestAsync('emits an error${E == Object ? '' : ' of type $E'}',
          (actual) async {
        if (!await actual.hasNext) {
          return Extracted.rejection(
              actual: ['a stream'],
              which: ['closed without emitting an expected error']);
        }
        try {
          final value = await actual.peek;
          return Extracted.rejection(
              actual: prefixFirst('a stream emitting value ', literal(value)),
              which: ['closed without emitting an error']);
        } on E catch (e) {
          await actual.next.then<void>((_) {}, onError: (_) {});
          return Extracted.value(e);
        } catch (e) {
          return Extracted.rejection(
              actual: prefixFirst('a stream with error ', literal(e)),
              which: ['emitted an error with an incorrect type, is not $E']);
        }
      });

  /// Expects that the `Stream` emits any number of events before emitting an
  /// event that satisfies [condition].
  ///
  /// Returns a `Future` that completes after the stream has emitted an event
  /// that satisfies [condition].
  ///
  /// Fails if the stream emits an error or closes before emitting a matching
  /// event.
  ///
  /// If this expectation fails, the source queue will be left in its original
  /// state.
  /// If this expectation succeeds, consumes the matching event and all prior
  /// events.
  Future<void> emitsThrough(Condition<T> condition) async {
    await _expectAsync(
        () => [
              'emits any values then emits a value that:',
              ...describe(condition)
            ], (actual) async {
      var count = 0;
      while (await actual.hasNext) {
        if (softCheck(await actual.next, condition) == null) {
          return null;
        }
        count++;
      }
      return Rejection(
          actual: ['a stream'],
          which: ['ended after emitting $count elements with none matching']);
    });
  }

  /// Expects that the stream satisfies each condition in [conditions] serially.
  ///
  /// Waits for each condition to be satisfied or rejected before checking the
  /// next. Subsequent conditions will not see any events consumed by earlier
  /// conditions.
  ///
  /// ```dart
  /// await checkThat(StreamQueue(someStream)).inOrder([
  ///   it()..emits().that(it()..equals(0)),
  ///   it()..emits().that(it()..equals(1)),
  //  ]);
  /// ```
  ///
  /// If this expectation fails, the source queue will be left in its original
  /// state.
  /// If this expectation succeeds, consumes as many events from the source
  /// stream as are consumed by all the conditions.
  Future<void> inOrder(Iterable<Condition<StreamQueue<T>>> conditions) async {
    conditions = conditions.toList();
    final descriptions = <String>[];
    await _expectAsync(
        () => descriptions.isEmpty
            ? ['satisfies ${conditions.length} conditions in order']
            : descriptions, (actual) async {
      var satisfiedCount = 0;
      for (var condition in conditions) {
        descriptions.addAll(await describeAsync(condition));
        final failure = await softCheckAsync(actual, condition);
        if (failure != null) {
          final which = failure.rejection.which;
          return Rejection(actual: [
            'a stream'
          ], which: [
            if (satisfiedCount > 0)
              'satisfied ${satisfiedCount} conditions then',
            'failed to satisfy the condition at index ${satisfiedCount}',
            if (failure.detail.depth > 0) ...[
              'because it:',
              ...indent(
                  failure.detail.actual.skip(1), failure.detail.depth - 1),
              ...indent(prefixFirst('Actual: ', failure.rejection.actual),
                  failure.detail.depth),
              if (which != null)
                ...indent(prefixFirst('Which: ', which), failure.detail.depth),
            ] else ...[
              if (which != null) ...prefixFirst('because it ', which),
            ],
          ]);
        }
        satisfiedCount++;
      }
      return null;
    });
  }

  /// Expects that the stream statisfies at least one condition from
  /// [conditions].
  ///
  /// If this expectation fails, the source queue will be left in its original
  /// state.
  /// If this expectation succeeds, consumes the same events from the source
  /// queue as the satisfied condition. If multiple conditions are satisfied,
  /// chooses the condition which consumed the most events.
  Future<void> anyOf(Iterable<Condition<StreamQueue<T>>> conditions) async {
    conditions = conditions.toList();
    if (conditions.isEmpty) {
      throw ArgumentError('conditions may not be empty');
    }
    final descriptions = <Iterable<String>>[];
    await context.expectAsync(
        () => descriptions.isEmpty
            ? ['satisfies any of ${conditions.length} conditions']
            : [
                'satisfies one of:',
                for (var i = 0; i < descriptions.length; i++) ...[
                  ...descriptions[i],
                  if (i < descriptions.length - 1) 'or,'
                ]
              ], (actual) async {
      final transaction = actual.startTransaction();
      StreamQueue<T>? longestAccepted;
      final descriptionFuture = Future.wait(conditions.map(describeAsync));
      final failures = await Future.wait(conditions.map((condition) async {
        final copy = transaction.newQueue();
        final failure = await softCheckAsync(copy, condition);
        if (failure == null &&
            (longestAccepted == null ||
                copy.eventsDispatched > longestAccepted!.eventsDispatched)) {
          longestAccepted = copy;
        }
        return failure;
      }));
      descriptions.addAll(await descriptionFuture);
      if (longestAccepted != null) {
        transaction.commit(longestAccepted!);
        return null;
      }
      transaction.reject();
      Iterable<String> _failureDetails(int index, CheckFailure? failure) {
        final actual = failure!.rejection.actual;
        final which = failure.rejection.which;
        final detail = failure.detail;
        final failed = 'failed the condition at index $index';
        if (detail.depth > 0) {
          return [
            '$failed because it:',
            ...indent(detail.actual.skip(1), detail.depth - 1),
            ...indent(prefixFirst('Actual: ', actual), detail.depth),
            if (which != null)
              ...indent(prefixFirst('Which: ', which), detail.depth),
          ];
        } else {
          return [
            if (which == null)
              failed
            else ...[
              '$failed because it:',
              ...indent(which),
            ],
          ];
        }
      }

      return Rejection(actual: [
        'a stream'
      ], which: [
        'failed to satisfy any condition',
        for (var i = 0; i < failures.length; i++)
          ..._failureDetails(i, failures[i]),
      ]);
    });
  }

  /// Expects that the stream closes without emitting any event that satisfies
  /// [condition].
  ///
  /// Returns a `Future` that completes after the stream has closed.
  ///
  /// Fails if the stream emits any even that satisfies [condition].
  ///
  /// If this expectation fails, the source queue will be left in its original
  /// state.
  /// If this expectation succeeds, consumes all the events that did not satisfy
  /// [condition] until the end of the stream.
  Future<void> neverEmits(Condition<T> condition) async {
    await _expectAsync(
        () => ['never emits a value that:', ...describe(condition)],
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

  /// Optionally consumes an event that matches [condition] from the stream.
  ///
  /// This expectation never fails.
  ///
  /// If a non-matching event is emitted, no events are consumed.
  /// If a matching event is emitted, that event is consumed.
  Future<void> mayEmit(Condition<T> condition) async {
    await context
        .expectAsync(() => ['may emit a value that:', ...describe(condition)],
            (actual) async {
      if (!await actual.hasNext) return null;
      try {
        final value = await actual.peek;
        if (softCheck(value, condition) == null) {
          await actual.next;
        }
      } finally {
        return null;
      }
    });
  }

  /// Optionally consumes events that match [condition] from the stream.
  ///
  /// This expectation never fails.
  ///
  /// Consumes matching events until one of the following happens:
  /// - A non-matching event is emitted.
  /// - An error is emitted.
  /// - The stream closes.
  Future<void> mayEmitMultiple(Condition<T> condition) async {
    await context
        .expectAsync(() => ['may emit a value that:', ...describe(condition)],
            (actual) async {
      while (await actual.hasNext) {
        try {
          final value = await actual.peek;
          if (softCheck(value, condition) == null) {
            await actual.next;
          } else {
            return null;
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    });
  }

  /// Expects that the stream closes without emitting any events or errors.
  ///
  /// If this expectation fails, the source queue will be left in its original
  /// state, the event or error that caused it to fail will not be consumed.
  Future<void> isDone() async {
    await _expectAsync(() => ['is done'], (actual) async {
      if (!await actual.hasNext) return null;
      try {
        return Rejection(
            actual: ['a stream'],
            which: prefixFirst(
                'emitted an unexpected value: ', literal(await actual.next)));
      } catch (e, st) {
        return Rejection(actual: [
          'a stream'
        ], which: [
          ...prefixFirst('emitted an unexpected error: ', literal(e)),
          ...(const LineSplitter()).convert(st.toString())
        ]);
      }
    });
  }
}

extension ChainAsync<T> on Future<Subject<T>> {
  /// Checks the expectations in [condition] against the result of this
  /// `Future`.
  ///
  /// Extensions written on [Subject] cannot be invoked on [Future<Check>]. This
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

extension StreamQueueWrap<T> on Subject<Stream<T>> {
  /// Wrap the stream in a [StreamQueue] to allow using checks from
  /// [StreamChecks].
  ///
  /// Stream expectations operate on a queue, instead of directly on the stream,
  /// so that they can support conditional expectations and check multiple
  /// possibilities from the same point in the stream.
  Subject<StreamQueue<T>> get withQueue =>
      context.nest('', (actual) => Extracted.value(StreamQueue(actual)),
          atSameLevel: true);
}
