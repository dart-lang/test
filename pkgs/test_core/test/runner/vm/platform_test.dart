// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_core/src/runner/vm/platform.dart';

void main() {
  group('FastFirst', () {
    test('returns the first event without awaiting onCancel', () async {
      var cancelCalled = false;
      final controller = StreamController<int>(
        onCancel: () {
          cancelCalled = true;
          return Completer<void>().future;
        },
      )..add(1);

      expect(await controller.stream.fastFirst, 1);
      expect(cancelCalled, isTrue);
    });

    test(
      'handles multiple synchronous events without throwing StateError',
      () async {
        final controller = StreamController<int>(sync: true);
        final future = controller.stream.fastFirst;
        controller
          ..add(1)
          ..add(2);

        expect(await future, 1);
      },
    );

    test(
      'handles multiple asynchronous events without throwing StateError',
      () async {
        final controller = StreamController<int>();
        final future = controller.stream.fastFirst;
        controller
          ..add(1)
          ..add(2);

        expect(await future, 1);
      },
    );

    test('propagates errors without unhandled zone errors', () async {
      final result = await _runFastFirstInGuardedZone(
        () => Stream<int>.error(
          StateError('boom'),
          StackTrace.fromString('test trace'),
        ),
      );

      expect(result.error, isStateError);
      expect(result.stackTrace.toString(), contains('test trace'));
      expect(result.unhandled, isEmpty);
    });

    test(
      'propagates errors without awaiting onCancel or unhandled zone errors',
      () async {
        var cancelCalled = false;
        final result = await _runFastFirstInGuardedZone(() {
          final controller =
              StreamController<int>(
                onCancel: () {
                  cancelCalled = true;
                  return Completer<void>().future;
                },
              )..addError(
                StateError('boom'),
                StackTrace.fromString('controller trace'),
              );
          return controller.stream;
        });

        expect(cancelCalled, isTrue);
        expect(result.error, isStateError);
        expect(result.stackTrace.toString(), contains('controller trace'));
        expect(result.unhandled, isEmpty);
      },
    );

    test('throws StateError on an empty stream', () async {
      await expectLater(const Stream<int>.empty().fastFirst, throwsStateError);
    });
  });
}

Future<({Object? error, StackTrace? stackTrace, List<Object> unhandled})>
_runFastFirstInGuardedZone(Stream<int> Function() createStream) async {
  final unhandled = <Object>[];
  Object? caughtError;
  StackTrace? caughtStackTrace;
  final done = Completer<void>();

  runZonedGuarded(
    () async {
      try {
        await createStream().fastFirst;
      } on Object catch (error, stackTrace) {
        caughtError = error;
        caughtStackTrace = stackTrace;
      } finally {
        await Future<void>.delayed(Duration.zero);
        done.complete();
      }
    },
    (error, stackTrace) {
      unhandled.add(error);
    },
  );

  await done.future;
  return (
    error: caughtError,
    stackTrace: caughtStackTrace,
    unhandled: unhandled,
  );
}
