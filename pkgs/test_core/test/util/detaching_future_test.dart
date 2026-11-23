// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_core/src/util/detaching_future.dart';

void main() {
  group('DetachingFuture', () {
    test('resolves to the value before and after completion', () async {
      final completer = Completer<int>();
      final detaching = DetachingFuture(completer.future);

      final beforeCompletion = detaching.asFuture;
      expect(identical(beforeCompletion, completer.future), isTrue);

      completer.complete(42);
      expect(await beforeCompletion, 42);

      final afterCompletion = detaching.asFuture;
      expect(identical(afterCompletion, completer.future), isFalse);
      expect(await afterCompletion, 42);
    });

    test('supports nullable values after completion', () async {
      final completer = Completer<String?>();
      final detaching = DetachingFuture(completer.future);

      completer.complete(null);
      await pumpEventQueue();

      expect(identical(detaching.asFuture, completer.future), isFalse);
      expect(await detaching.asFuture, isNull);
    });

    test(
      'retains an error on asFuture without an unhandled zone error',
      () async {
        final zoneErrors = <Object>[];
        Object? caughtBeforeCompletion;
        Object? caughtAfterCompletion;

        await runZonedGuarded(
          () async {
            final completer = Completer<int>();
            final detaching = DetachingFuture(completer.future);

            final beforeCompletion = detaching.asFuture.then<Object?>(
              (value) => value,
              onError: (Object error) => error,
            );

            completer.completeError(StateError('boom'));
            caughtBeforeCompletion = await beforeCompletion;

            try {
              await detaching.asFuture;
            } on Object catch (error) {
              caughtAfterCompletion = error;
            }

            await pumpEventQueue();
          },
          (error, _) {
            zoneErrors.add(error);
          },
        );

        expect(caughtBeforeCompletion, isA<StateError>());
        expect(caughtAfterCompletion, isA<StateError>());
        expect(zoneErrors, isEmpty);
      },
    );

    test(
      'retains an error when inProgress rejects before asFuture is read',
      () async {
        final zoneErrors = <Object>[];
        Object? caughtError;

        await runZonedGuarded(
          () async {
            final completer = Completer<int>();
            final detaching = DetachingFuture(completer.future);

            completer.completeError(StateError('boom'));
            await pumpEventQueue();

            try {
              await detaching.asFuture;
            } on Object catch (error) {
              caughtError = error;
            }
          },
          (error, _) {
            zoneErrors.add(error);
          },
        );

        expect(caughtError, isA<StateError>());
        expect(zoneErrors, isEmpty);
      },
    );
  });
}
