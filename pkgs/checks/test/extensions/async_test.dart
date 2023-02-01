// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';
import 'package:test_api/hooks.dart';

import '../test_shared.dart';

void main() {
  group('FutureChecks', () {
    group('completes', () {
      test('succeeds for a future that completes to a value', () async {
        await (_futureSuccess()).must.complete().which(would()..equal(42));
      });
      test('rejects futures which complete as errors', () async {
        await (_futureFail()).must.beRejectedByAsync(
          would()..complete().which(would()..equal(1)),
          actual: ['a future that completes as an error'],
          which: ['threw <UnimplementedError> at:', 'fake trace'],
        );
      });
      test('can be described', () async {
        await (would<Future<void>>()..complete())
            .must
            .haveAsyncDescription
            .which(would()..deeplyEqual(['  completes to a value']));
        await (would<Future<int>>()..complete().which(would()..equal(42)))
            .must
            .haveAsyncDescription
            .which(would()
              ..deeplyEqual([
                '  completes to a value that:',
                '    equals <42>',
              ]));
      });
    });

    group('throws', () {
      test(
          'succeeds for a future that compeletes to an error of the expected type',
          () async {
        await (_futureFail())
            .must
            .throwException<UnimplementedError>()
            .which(would()..have((p0) => p0.message, 'message').beNull());
      });
      test('fails for futures that complete to a value', () async {
        await (_futureSuccess()).must.beRejectedByAsync(
          would()..throwException(),
          actual: ['completed to <42>'],
          which: ['did not throw'],
        );
      });
      test('failes for futures that complete to an error of the wrong type',
          () async {
        await (_futureFail()).must.beRejectedByAsync(
          would()..throwException<StateError>(),
          actual: ['completed to error <UnimplementedError>'],
          which: [
            'threw an exception that is not a StateError at:',
            'fake trace'
          ],
        );
      });
      test('can be described', () async {
        await (would<Future<void>>()..throwException())
            .must
            .haveAsyncDescription
            .which(would()..deeplyEqual(['  completes to an error']));
        await (would<Future<void>>()..throwException<StateError>())
            .must
            .haveAsyncDescription
            .which(would()
              ..deeplyEqual(['  completes to an error of type StateError']));
      });
    });

    group('doesNotComplete', () {
      test('succeeds for a Future that never completes', () async {
        (Completer<void>().future).must.neverComplete();
      });
      test('fails for a Future that completes as a value', () async {
        Object? testFailure;
        runZonedGuarded(() {
          final completer = Completer<String>();
          (completer.future).must.neverComplete();
          completer.complete('value');
        }, (e, st) {
          testFailure = e;
        });
        await pumpEventQueue();
        testFailure.must
            .beA<TestFailure>()
            .have((f) => f.message, 'message')
            .beNonNull()
            .equal('''
Expected: a Future<String> that:
  does not complete
Actual: a future that completed to 'value\'''');
      });
      test('fails for a Future that completes as an error', () async {
        Object? testFailure;
        runZonedGuarded(() {
          final completer = Completer<String>();
          (completer.future).must.neverComplete();
          completer.completeError('error', StackTrace.fromString('fake trace'));
        }, (e, st) {
          testFailure = e;
        });
        await pumpEventQueue();
        testFailure.must
            .beA<TestFailure>()
            .have((f) => f.message, 'message')
            .beNonNull()
            .equal('''
Expected: a Future<String> that:
  does not complete
Actual: a future that completed as an error:
Which: threw 'error'
fake trace''');
      });
      test('can be described', () async {
        await (would<Future<void>>()..neverComplete())
            .must
            .haveAsyncDescription
            .which(would()..deeplyEqual(['  does not complete']));
      });
    });
  });

  group('StreamChecks', () {
    group('emits', () {
      test('succeeds for a stream that emits a value', () async {
        await (_countingStream(5)).must.emit().which(would()..equal(0));
      });
      test('fails for a stream that closes without emitting', () async {
        await (_countingStream(0)).must.beRejectedByAsync(
          would()..emit(),
          actual: ['a stream'],
          which: ['closed without emitting enough values'],
        );
      });
      test('fails for a stream that emits an error', () async {
        await (_countingStream(1, errorAt: 0)).must.beRejectedByAsync(
          would()..emit(),
          actual: ['a stream with error <UnimplementedError: Error at 1>'],
          which: ['emitted an error instead of a value at:', 'fake trace'],
        );
      });
      test('can be described', () async {
        await (would<StreamQueue<void>>()..emit())
            .must
            .haveAsyncDescription
            .which(would()..deeplyEqual(['  emits a value']));
        await (would<StreamQueue<int>>()..emit().which(would()..equal(42)))
            .must
            .haveAsyncDescription
            .which(would()
              ..deeplyEqual([
                '  emits a value that:',
                '    equals <42>',
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1, errorAt: 0);
        await softCheckAsync<StreamQueue<int>>(queue, would()..emit());
        await queue.must.emitError();
      });
    });

    group('emitsError', () {
      test('succeeds for a stream that emits an error', () async {
        await (_countingStream(1, errorAt: 0))
            .must
            .emitError<UnimplementedError>();
      });
      test('fails for a stream that closes without emitting an error',
          () async {
        await (_countingStream(0)).must.beRejectedByAsync(
          would()..emitError(),
          actual: ['a stream'],
          which: ['closed without emitting an expected error'],
        );
      });
      test('fails for a stream that emits value', () async {
        await (_countingStream(1)).must.beRejectedByAsync(
          would()..emitError(),
          actual: ['a stream emitting value <0>'],
          which: ['closed without emitting an error'],
        );
      });
      test('fails for a stream that emits an error of the incorrect type',
          () async {
        await (_countingStream(1, errorAt: 0)).must.beRejectedByAsync(
          would()..emitError<StateError>(),
          actual: ['a stream with error <UnimplementedError: Error at 1>'],
          which: ['emitted an error which is not StateError at:', 'fake trace'],
        );
      });
      test('can be described', () async {
        await (would<StreamQueue<void>>()..emitError())
            .must
            .haveAsyncDescription
            .which(would()..deeplyEqual(['  emits an error']));
        await (would<StreamQueue<void>>()..emitError<StateError>())
            .must
            .haveAsyncDescription
            .which(
                would()..deeplyEqual(['  emits an error of type StateError']));
        await (would<StreamQueue<void>>()
              ..emitError<StateError>().which(
                  would()..have((e) => e.message, 'message').equal('foo')))
            .must
            .haveAsyncDescription
            .which(would()
              ..deeplyEqual([
                '  emits an error of type StateError that:',
                '    has message that:',
                '      equals \'foo\''
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync<StreamQueue<int>>(queue, would()..emitError());
        await queue.must.emit().which((would()..equal(0)));
      });
    });

    group('emitsThrough', () {
      test('succeeds for a stream that eventuall emits a matching value',
          () async {
        await (_countingStream(5)).must.emitThrough(would()..equal(4));
      });
      test('fails for a stream that closes without emitting a matching value',
          () async {
        await (_countingStream(4)).must.beRejectedByAsync(
          would()..emitThrough(would()..equal(5)),
          actual: ['a stream'],
          which: ['ended after emitting 4 elements with none matching'],
        );
      });
      test('can be described', () async {
        await (would<StreamQueue<int>>()..emitThrough(would()..equal(42)))
            .must
            .haveAsyncDescription
            .which(would()
              ..deeplyEqual([
                '  emits any values then emits a value that:',
                '    equals <42>'
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync(
            queue, would<StreamQueue<int>>()..emitThrough(would()..equal(42)));
        queue.must.emit().which(would()..equal(0));
      });
      test('consumes events', () async {
        final queue = _countingStream(3);
        await queue.must.emitThrough(would()..equal(1));
        await queue.must.emit().which((would()..equal(2)));
      });
    });

    group('emitsInOrder', () {
      test('succeeds for happy case', () async {
        await (_countingStream(2)).must.inOrder([
          would()..emit().which(would()..equal(0)),
          would()..emit().which((would()..equal(1))),
          would()..beDone(),
        ]);
      });
      test('reports which condition failed', () async {
        await (_countingStream(1)).must.beRejectedByAsync(
          would()..inOrder([would()..emit(), would()..emit()]),
          actual: ['a stream'],
          which: [
            'satisfied 1 conditions then',
            'failed to satisfy the condition at index 1',
            'because it closed without emitting enough values'
          ],
        );
      });
      test('nestes the report for deep failures', () async {
        await (_countingStream(2)).must.beRejectedByAsync(
          would()
            ..inOrder(
                [would()..emit(), would()..emit().which(would()..equal(2))]),
          actual: ['a stream'],
          which: [
            'satisfied 1 conditions then',
            'failed to satisfy the condition at index 1',
            'because it:',
            '  emits a value that:',
            '  Actual: <1>',
            '  Which: are not equal',
          ],
        );
      });
      test('gets described with the number of conditions', () async {
        await (would<StreamQueue<int>>()..inOrder([would(), would()]))
            .must
            .haveAsyncDescription
            .which(would()..deeplyEqual(['  satisfies 2 conditions in order']));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(3);
        await softCheckAsync<StreamQueue<int>>(
            queue,
            would()
              ..inOrder([
                would()..emit().which(would()..equal(0)),
                would()..emit().which(would()..equal(1)),
                would()..emit().which(would()..equal(42)),
              ]));
        await queue.must.inOrder([
          would()..emit().which(would()..equal(0)),
          would()..emit().which(would()..equal(1)),
          would()..emit().which(would()..equal(2)),
          would()..beDone(),
        ]);
      });
      test('consumes events', () async {
        final queue = _countingStream(3);
        await queue.must.inOrder([would()..emit(), would()..emit()]);
        await queue.must.emit().which(would()..equal(2));
      });
    });

    group('neverEmits', () {
      test(
          'succeeds for a stream that closes without emitting a matching value',
          () async {
        await (_countingStream(5)).must.neverEmit(would()..equal(5));
      });
      test('fails for a stream that emits a matching value', () async {
        await (_countingStream(6)).must.beRejectedByAsync(
          would()..neverEmit(would()..equal(5)),
          actual: ['a stream'],
          which: ['emitted <5>', 'following 5 other items'],
        );
      });
      test('can be described', () async {
        await (would<StreamQueue<int>>()..neverEmit(would()..equal(42)))
            .must
            .haveAsyncDescription
            .which(would()
              ..deeplyEqual([
                '  never emits a value that:',
                '    equals <42>',
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, would()..neverEmit(would()..equal(1)));
        await queue.must.inOrder([
          would()..emit().which(would()..equal(0)),
          would()..emit().which(would()..equal(1)),
          would()..beDone(),
        ]);
      });
    });

    group('mayEmit', () {
      test('succeeds for a stream that emits a matching value', () async {
        await (_countingStream(1)).must.maybeEmit(would()..equal(0));
      });
      test('succeeds for a stream that emits an error', () async {
        await (_countingStream(1, errorAt: 0))
            .must
            .maybeEmit(would()..equal(0));
      });
      test('succeeds for a stream that closes', () async {
        await (_countingStream(0)).must.maybeEmit(would()..equal(42));
      });
      test('consumes a matching event', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, would()..maybeEmit(would()..equal(0)));
        await queue.must.emit().which(would()..equal(1));
      });
      test('does not consume a non-matching event', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, would()..maybeEmit(would()..equal(1)));
        await queue.must.emit().which(would()..equal(0));
      });
      test('does not consume an error', () async {
        final queue = _countingStream(1, errorAt: 0);
        await softCheckAsync<StreamQueue<int>>(
            queue, would()..maybeEmit(would()..equal(0)));
        await queue.must.emitError<UnimplementedError>().which(
            would()..have((e) => e.message, 'message').equal('Error at 1'));
      });
    });

    group('mayEmitMultiple', () {
      test('succeeds for a stream that emits a matching value', () async {
        await (_countingStream(1)).must.maybeEmitMultiple(would()..equal(0));
      });
      test('succeeds for a stream that emits an error', () async {
        await (_countingStream(1, errorAt: 0))
            .must
            .maybeEmitMultiple(would()..equal(0));
      });
      test('succeeds for a stream that closes', () async {
        await (_countingStream(0)).must.maybeEmitMultiple(would()..equal(42));
      });
      test('consumes matching events', () async {
        final queue = _countingStream(3);
        await softCheckAsync<StreamQueue<int>>(
            queue, would()..maybeEmitMultiple(would()..beLessThat(2)));
        await queue.must.emit().which(would()..equal(2));
      });
      test('consumes no events if no events match', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, would()..maybeEmitMultiple(would()..beLessThat(0)));
        await queue.must.emit().which(would()..equal(0));
      });
      test('does not consume an error', () async {
        final queue = _countingStream(1, errorAt: 0);
        await softCheckAsync<StreamQueue<int>>(
            queue, would()..maybeEmitMultiple(would()..equal(0)));
        await queue.must.emitError<UnimplementedError>().which(
            would()..have((e) => e.message, 'message').equal('Error at 1'));
      });
    });

    group('isDone', () {
      test('succeeds for an empty stream', () async {
        await (_countingStream(0)).must.beDone();
      });
      test('fails for a stream that emits a value', () async {
        await (_countingStream(1)).must.beRejectedByAsync(would()..beDone(),
            actual: ['a stream'], which: ['emitted an unexpected value: <0>']);
      });
      test('fails for a stream that emits an error', () async {
        final controller = StreamController<void>();
        controller.addError('sad', StackTrace.fromString('fake trace'));
        await StreamQueue(controller.stream).must.beRejectedByAsync(
            would()..beDone(),
            actual: ['a stream'],
            which: ['emitted an unexpected error: \'sad\'', 'fake trace']);
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync<StreamQueue<int>>(queue, would()..beDone());
        await queue.must.emit().which(would()..equal(0));
      });
      test('can be described', () async {
        await (would<StreamQueue<int>>()..beDone())
            .must
            .haveAsyncDescription
            .which(would()..deeplyEqual(['  is done']));
      });
    });

    group('emitsAnyOf', () {
      test('succeeds for a stream that matches one condition', () async {
        await (_countingStream(1)).must.anyOf([
          would()..emit().which(would()..equal(42)),
          would()..emit().which((would()..equal(0)))
        ]);
      });
      test('fails for a stream that matches no conditions', () async {
        await (_countingStream(0)).must.beRejectedByAsync(
            would()
              ..anyOf([
                would()..emit(),
                would()..emitThrough(would()..equal(1)),
              ]),
            actual: [
              'a stream'
            ],
            which: [
              'failed to satisfy any condition',
              'failed the condition at index 0 because it:',
              '  closed without emitting enough values',
              'failed the condition at index 1 because it:',
              '  ended after emitting 0 elements with none matching',
            ]);
      });
      test('includes nested details for nested failures', () async {
        await (_countingStream(1)).must.beRejectedByAsync(
            would()
              ..anyOf([
                would()..emit().which(would()..equal(42)),
                would()..emitThrough(would()..equal(10)),
              ]),
            actual: [
              'a stream'
            ],
            which: [
              'failed to satisfy any condition',
              'failed the condition at index 0 because it:',
              '  emits a value that:',
              '  Actual: <0>',
              '  Which: are not equal',
              'failed the condition at index 1 because it:',
              '  ended after emitting 1 elements with none matching',
            ]);
      });
      test('gets described with the number of conditions', () async {
        await (would<StreamQueue<int>>()
              ..anyOf([would()..emit(), would()..emit()]))
            .must
            .haveAsyncDescription
            .which(would()..deeplyEqual(['  satisfies any of 2 conditions']));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync<StreamQueue<int>>(
            queue,
            would()
              ..anyOf([
                would()..emit().which(would()..equal(10)),
                would()..emitThrough(would()..equal(42)),
              ]));
        await queue.must.emit().which(would()..equal(0));
      });
      test('consumes events', () async {
        final queue = _countingStream(3);
        await queue.must.anyOf([
          would()..emit().which(would()..equal(1)),
          would()..emitThrough(would()..equal(1))
        ]);
        await queue.must.emit().which(would()..equal(2));
      });
    });
  });

  group('ChainAsync', () {
    test('which', () async {
      await (_futureSuccess()).must.complete().which(would()..equal(42));
    });
  });

  group('StreamQueueWrap', () {
    test('can wrap streams in a queue', () async {
      await Stream.value(1).withQueue.must.emit();
    });
  });
}

Future<int> _futureSuccess() => Future.microtask(() => 42);

Future<int> _futureFail() =>
    Future.error(UnimplementedError(), StackTrace.fromString('fake trace'));

StreamQueue<int> _countingStream(int count, {int? errorAt}) => StreamQueue(
      Stream.fromIterable(
        Iterable<int>.generate(count, (index) {
          if (index == errorAt) {
            Error.throwWithStackTrace(UnimplementedError('Error at $count'),
                StackTrace.fromString('fake trace'));
          }
          return index;
        }),
      ),
    );
