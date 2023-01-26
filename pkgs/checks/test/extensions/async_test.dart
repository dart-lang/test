// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:test_api/hooks.dart';

import '../test_shared.dart';

void main() {
  group('FutureChecks', () {
    test('completes', () async {
      (await checkThat(_futureSuccess()).completes()).equals(42);

      await checkThat(_futureFail()).isRejectedByAsync(
        it()..completes().that(it()..equals(1)),
        actual: ['A future that completes as an error'],
        which: ['Threw <UnimplementedError>'],
      );
    });

    test('throws', () async {
      (await checkThat(_futureFail()).throws<UnimplementedError>())
          .has((p0) => p0.message, 'message')
          .isNull();

      await checkThat(_futureSuccess()).isRejectedByAsync(
        it()..throws(),
        actual: ['Completed to <42>'],
        which: ['Did not throw'],
      );

      await checkThat(_futureFail()).isRejectedByAsync(
        it()..throws<StateError>(),
        actual: ['Completed to error <UnimplementedError>'],
        which: ['Is not an StateError'],
      );
    });

    group('doesNotComplete', () {
      test('succeeds for a Future that never completes', () async {
        checkThat(Completer<void>().future).doesNotComplete();
      });
      test('fails for a Future that completes as a value', () async {
        Object? testFailure;
        runZonedGuarded(() {
          final completer = Completer<String>();
          checkThat(completer.future).doesNotComplete();
          completer.complete('value');
        }, (e, st) {
          testFailure = e;
        });
        await pumpEventQueue();
        checkThat(testFailure)
            .isA<TestFailure>()
            .has((f) => f.message, 'message')
            .isNotNull()
            .equals('''
Expected: a Future<String> that:
  does not complete as value or error
Actual: A future that completed to 'value\'''');
      });
      test('fails for a Future that completes as an error', () async {
        Object? testFailure;
        runZonedGuarded(() {
          final completer = Completer<String>();
          checkThat(completer.future).doesNotComplete();
          completer.completeError('error', StackTrace.fromString('fake trace'));
        }, (e, st) {
          testFailure = e;
        });
        await pumpEventQueue();
        checkThat(testFailure)
            .isA<TestFailure>()
            .has((f) => f.message, 'message')
            .isNotNull()
            .equals('''
Expected: a Future<String> that:
  does not complete as value or error
Actual: A future that completed as an error:
Which: threw 'error'
fake trace''');
      });
    });
  });

  group('StreamChecks', () {
    test('emits', () async {
      (await checkThat(_countingStream(5)).emits()).equals(0);

      await checkThat(_countingStream(0)).isRejectedByAsync(
        it()..emits(),
        actual: ['an empty stream'],
        which: ['did not emit any value'],
      );

      await checkThat(_countingStream(1, errorAt: 0)).isRejectedByAsync(
        it()..emits(),
        actual: ['A stream with error <UnimplementedError: Error at 1>'],
        which: ['emitted an error instead of a value'],
      );
    });

    test('emitsThrough', () async {
      await checkThat(_countingStream(5)).emitsThrough(it()..equals(4));

      await checkThat(_countingStream(4)).isRejectedByAsync(
        it()..emitsThrough(it()..equals(5)),
        actual: ['a stream'],
        which: ['ended after emitting 4 elements with none matching'],
      );
    });

    test('neverEmits', () async {
      await checkThat(_countingStream(5)).neverEmits(it()..equals(5));

      await checkThat(_countingStream(6)).isRejectedByAsync(
        it()..neverEmits(it()..equals(5)),
        actual: ['a stream'],
        which: ['emitted <5>', 'following 5 other items'],
      );
    });
  });

  group('ChainAsync', () {
    test('that', () async {
      await checkThat(_futureSuccess()).completes().that(it()..equals(42));
    });
  });
}

Future<int> _futureSuccess() => Future.microtask(() => 42);

Future<int> _futureFail() => Future.error(UnimplementedError());

StreamQueue<int> _countingStream(int count, {int? errorAt}) => StreamQueue(
      Stream.fromIterable(
        Iterable<int>.generate(count, (index) {
          if (index == errorAt) throw UnimplementedError('Error at $count');
          return index;
        }),
      ),
    );
