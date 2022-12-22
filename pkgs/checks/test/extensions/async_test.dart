// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:checks/checks.dart';
import 'package:checks/src/checks.dart' show softCheckAsync;
import 'package:test/scaffolding.dart';
import 'package:test_api/hooks.dart';

void main() {
  group('FutureChecks', () {
    test('completes', () async {
      (await checkThat(_futureSuccess()).completes()).equals(42);

      await _rejectionWhichCheck(
        _futureFail(),
        (f) async => await f.completes(),
        (check) => check.single.equals('Threw UnimplementedError'),
      );
    });

    test('throws', () async {
      (await checkThat(_futureFail()).throws<UnimplementedError>())
          .has((p0) => p0.message, 'message')
          .isNull();

      await _rejectionWhichCheck(
        _futureSuccess(),
        (f) async => await f.throws(),
        (check) => check.single.equals('Did not throw'),
      );

      await _rejectionWhichCheck(
        _futureFail(),
        (f) async => await f.throws<StateError>(),
        (check) => check.single.equals('Is not an StateError'),
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

      await _rejectionWhichCheck(
        _countingStream(0),
        (f) async => await f.emits(),
        (check) => check.single.equals('did not emit any value'),
      );

      await _rejectionWhichCheck(
        _countingStream(0),
        (f) async => await f.emits(),
        (check) => check.single.equals('did not emit any value'),
      );

      await _rejectionWhichCheck(
        _countingStream(1, errorAt: 0),
        (f) async => await f.emits(),
        (check) => check.single.equals('emitted an error instead of a value'),
      );
    });

    test('emitsThrough', () async {
      await checkThat(_countingStream(5)).emitsThrough((p0) {
        p0.equals(4);
      });

      await _rejectionWhichCheck(
        _countingStream(4),
        (f) async => await f.emitsThrough((p0) => p0.equals(5)),
        (check) => check.single
            .equals('ended after emitting 4 elements with none matching'),
      );
    });

    test('neverEmits', () async {
      await checkThat(_countingStream(5)).neverEmits((p0) => p0.equals(5));

      await _rejectionWhichCheck(
        _countingStream(6),
        (f) async => await f.neverEmits((p0) => p0.equals(5)),
        (check) => check
          ..length.equals(2)
          ..first.equals('emitted <5>')
          ..last.equals('following 5 other items'),
      );
    });
  });

  group('ChainAsync', () {
    test('that', () async {
      await checkThat(_futureSuccess()).completes().that((r) => r.equals(42));
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

Future<void> _rejectionWhichCheck<T>(
  T value,
  Future<void> Function(Check<T>) condition,
  void Function(Check<Iterable<String>>) whichCheck,
) async {
  final failure = await softCheckAsync(value, condition);
  whichCheck(checkThat(failure)
      .isNotNull()
      .has((f) => f.rejection, 'rejection')
      .has((r) => r.which, 'which')
      .isNotNull());
}
