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
        await check(_futureSuccess()).completes(it()..equals(42));
      });
      test('rejects futures which complete as errors', () async {
        await check(_futureFail()).isRejectedByAsync(
          it()..completes(it()..equals(1)),
          actual: ['a future that completes as an error'],
          which: ['threw <UnimplementedError> at:', 'fake trace'],
        );
      });
      test('can be described', () async {
        await check(it<Future<void>>()..completes()).hasAsyncDescriptionWhich(
            it()..deepEquals(['  completes to a value']));
        await check(it<Future<int>>()..completes(it()..equals(42)))
            .hasAsyncDescriptionWhich(it()
              ..deepEquals([
                '  completes to a value that:',
                '    equals <42>',
              ]));
      });
    });

    group('throws', () {
      test(
          'succeeds for a future that compeletes to an error of the expected type',
          () async {
        await check(_futureFail()).throws<UnimplementedError>(
            it()..has((p0) => p0.message, 'message').isNull());
      });
      test('fails for futures that complete to a value', () async {
        await check(_futureSuccess()).isRejectedByAsync(
          it()..throws(),
          actual: ['completed to <42>'],
          which: ['did not throw'],
        );
      });
      test('failes for futures that complete to an error of the wrong type',
          () async {
        await check(_futureFail()).isRejectedByAsync(
          it()..throws<StateError>(),
          actual: ['completed to error <UnimplementedError>'],
          which: [
            'threw an exception that is not a StateError at:',
            'fake trace'
          ],
        );
      });
      test('can be described', () async {
        await check(it<Future<void>>()..throws()).hasAsyncDescriptionWhich(
            it()..deepEquals(['  completes to an error']));
        await check(it<Future<void>>()..throws<StateError>())
            .hasAsyncDescriptionWhich(it()
              ..deepEquals(['  completes to an error of type StateError']));
      });
    });

    group('doesNotComplete', () {
      test('succeeds for a Future that never completes', () async {
        check(Completer<void>().future).doesNotComplete();
      });
      test('fails for a Future that completes as a value', () async {
        Object? testFailure;
        runZonedGuarded(() {
          final completer = Completer<String>();
          check(completer.future).doesNotComplete();
          completer.complete('value');
        }, (e, st) {
          testFailure = e;
        });
        await pumpEventQueue();
        check(testFailure)
            .isA<TestFailure>()
            .has((f) => f.message, 'message')
            .isNotNull()
            .equals('''
Expected: a Future<String> that:
  does not complete
Actual: a future that completed to 'value\'''');
      });
      test('fails for a Future that completes as an error', () async {
        Object? testFailure;
        runZonedGuarded(() {
          final completer = Completer<String>();
          check(completer.future).doesNotComplete();
          completer.completeError('error', StackTrace.fromString('fake trace'));
        }, (e, st) {
          testFailure = e;
        });
        await pumpEventQueue();
        check(testFailure)
            .isA<TestFailure>()
            .has((f) => f.message, 'message')
            .isNotNull()
            .equals('''
Expected: a Future<String> that:
  does not complete
Actual: a future that completed as an error:
Which: threw 'error'
fake trace''');
      });
      test('can be described', () async {
        await check(it<Future<void>>()..doesNotComplete())
            .hasAsyncDescriptionWhich(
                it()..deepEquals(['  does not complete']));
      });
    });
  });

  group('StreamChecks', () {
    group('emits', () {
      test('succeeds for a stream that emits a value', () async {
        await check(_countingStream(5)).emits(it()..equals(0));
      });
      test('fails for a stream that closes without emitting', () async {
        await check(_countingStream(0)).isRejectedByAsync(
          it()..emits(),
          actual: ['a stream'],
          which: ['closed without emitting enough values'],
        );
      });
      test('fails for a stream that emits an error', () async {
        await check(_countingStream(1, errorAt: 0)).isRejectedByAsync(
          it()..emits(),
          actual: ['a stream with error <UnimplementedError: Error at 1>'],
          which: ['emitted an error instead of a value at:', 'fake trace'],
        );
      });
      test('can be described', () async {
        await check(it<StreamQueue<void>>()..emits())
            .hasAsyncDescriptionWhich(it()..deepEquals(['  emits a value']));
        await check(it<StreamQueue<int>>()..emits(it()..equals(42)))
            .hasAsyncDescriptionWhich(it()
              ..deepEquals([
                '  emits a value that:',
                '    equals <42>',
              ]));
      });
      test('does not consume error', () async {
        final queue = _countingStream(1, errorAt: 0);
        await softCheckAsync<StreamQueue<int>>(queue, it()..emits());
        await check(queue).emitsError();
      });
    });

    group('emitsError', () {
      test('succeeds for a stream that emits an error', () async {
        await check(_countingStream(1, errorAt: 0))
            .emitsError<UnimplementedError>();
      });
      test('fails for a stream that closes without emitting an error',
          () async {
        await check(_countingStream(0)).isRejectedByAsync(
          it()..emitsError(),
          actual: ['a stream'],
          which: ['closed without emitting an expected error'],
        );
      });
      test('fails for a stream that emits value', () async {
        await check(_countingStream(1)).isRejectedByAsync(
          it()..emitsError(),
          actual: ['a stream emitting value <0>'],
          which: ['closed without emitting an error'],
        );
      });
      test('fails for a stream that emits an error of the incorrect type',
          () async {
        await check(_countingStream(1, errorAt: 0)).isRejectedByAsync(
          it()..emitsError<StateError>(),
          actual: ['a stream with error <UnimplementedError: Error at 1>'],
          which: ['emitted an error which is not StateError at:', 'fake trace'],
        );
      });
      test('can be described', () async {
        await check(it<StreamQueue<void>>()..emitsError())
            .hasAsyncDescriptionWhich(it()..deepEquals(['  emits an error']));
        await check(it<StreamQueue<void>>()..emitsError<StateError>())
            .hasAsyncDescriptionWhich(
                it()..deepEquals(['  emits an error of type StateError']));
        await check(it<StreamQueue<void>>()
              ..emitsError<StateError>(
                  it()..has((e) => e.message, 'message').equals('foo')))
            .hasAsyncDescriptionWhich(it()
              ..deepEquals([
                '  emits an error of type StateError that:',
                '    has message that:',
                '      equals \'foo\''
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync<StreamQueue<int>>(queue, it()..emitsError());
        await check(queue).emits((it()..equals(0)));
      });
    });

    group('emitsThrough', () {
      test('succeeds for a stream that eventuall emits a matching value',
          () async {
        await check(_countingStream(5)).emitsThrough(it()..equals(4));
      });
      test('fails for a stream that closes without emitting a matching value',
          () async {
        await check(_countingStream(4)).isRejectedByAsync(
          it()..emitsThrough(it()..equals(5)),
          actual: ['a stream'],
          which: ['ended after emitting 4 elements with none matching'],
        );
      });
      test('can be described', () async {
        await check(it<StreamQueue<int>>()..emitsThrough(it()..equals(42)))
            .hasAsyncDescriptionWhich(it()
              ..deepEquals([
                '  emits any values then emits a value that:',
                '    equals <42>'
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync(
            queue, it<StreamQueue<int>>()..emitsThrough(it()..equals(42)));
        check(queue).emits(it()..equals(0));
      });
      test('consumes events', () async {
        final queue = _countingStream(3);
        await check(queue).emitsThrough(it()..equals(1));
        await check(queue).emits((it()..equals(2)));
      });
    });

    group('emitsInOrder', () {
      test('succeeds for happy case', () async {
        await check(_countingStream(2)).inOrder([
          it()..emits(it()..equals(0)),
          it()..emits(it()..equals(1)),
          it()..isDone(),
        ]);
      });
      test('reports which condition failed', () async {
        await check(_countingStream(1)).isRejectedByAsync(
          it()..inOrder([it()..emits(), it()..emits()]),
          actual: ['a stream'],
          which: [
            'satisfied 1 conditions then',
            'failed to satisfy the condition at index 1',
            'because it closed without emitting enough values'
          ],
        );
      });
      test('nestes the report for deep failures', () async {
        await check(_countingStream(2)).isRejectedByAsync(
          it()..inOrder([it()..emits(), it()..emits(it()..equals(2))]),
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
        await check(it<StreamQueue<int>>()..inOrder([it(), it()]))
            .hasAsyncDescriptionWhich(
                it()..deepEquals(['  satisfies 2 conditions in order']));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(3);
        await softCheckAsync<StreamQueue<int>>(
            queue,
            it()
              ..inOrder([
                it()..emits(it()..equals(0)),
                it()..emits(it()..equals(1)),
                it()..emits(it()..equals(42)),
              ]));
        await check(queue).inOrder([
          it()..emits(it()..equals(0)),
          it()..emits(it()..equals(1)),
          it()..emits(it()..equals(2)),
          it()..isDone(),
        ]);
      });
      test('consumes events', () async {
        final queue = _countingStream(3);
        await check(queue).inOrder([it()..emits(), it()..emits()]);
        await check(queue).emits(it()..equals(2));
      });
    });

    group('neverEmits', () {
      test(
          'succeeds for a stream that closes without emitting a matching value',
          () async {
        await check(_countingStream(5)).neverEmits(it()..equals(5));
      });
      test('fails for a stream that emits a matching value', () async {
        await check(_countingStream(6)).isRejectedByAsync(
          it()..neverEmits(it()..equals(5)),
          actual: ['a stream'],
          which: ['emitted <5>', 'following 5 other items'],
        );
      });
      test('can be described', () async {
        await check(it<StreamQueue<int>>()..neverEmits(it()..equals(42)))
            .hasAsyncDescriptionWhich(it()
              ..deepEquals([
                '  never emits a value that:',
                '    equals <42>',
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..neverEmits(it()..equals(1)));
        await check(queue).inOrder([
          it()..emits(it()..equals(0)),
          it()..emits(it()..equals(1)),
          it()..isDone(),
        ]);
      });
    });

    group('mayEmit', () {
      test('succeeds for a stream that emits a matching value', () async {
        await check(_countingStream(1)).mayEmit(it()..equals(0));
      });
      test('succeeds for a stream that emits an error', () async {
        await check(_countingStream(1, errorAt: 0)).mayEmit(it()..equals(0));
      });
      test('succeeds for a stream that closes', () async {
        await check(_countingStream(0)).mayEmit(it()..equals(42));
      });
      test('consumes a matching event', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmit(it()..equals(0)));
        await check(queue).emits(it()..equals(1));
      });
      test('does not consume a non-matching event', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmit(it()..equals(1)));
        await check(queue).emits(it()..equals(0));
      });
      test('does not consume an error', () async {
        final queue = _countingStream(1, errorAt: 0);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmit(it()..equals(0)));
        await check(queue).emitsError<UnimplementedError>(
            it()..has((e) => e.message, 'message').equals('Error at 1'));
      });
    });

    group('mayEmitMultiple', () {
      test('succeeds for a stream that emits a matching value', () async {
        await check(_countingStream(1)).mayEmitMultiple(it()..equals(0));
      });
      test('succeeds for a stream that emits an error', () async {
        await check(_countingStream(1, errorAt: 0))
            .mayEmitMultiple(it()..equals(0));
      });
      test('succeeds for a stream that closes', () async {
        await check(_countingStream(0)).mayEmitMultiple(it()..equals(42));
      });
      test('consumes matching events', () async {
        final queue = _countingStream(3);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmitMultiple(it()..isLessThan(2)));
        await check(queue).emits(it()..equals(2));
      });
      test('consumes no events if no events match', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmitMultiple(it()..isLessThan(0)));
        await check(queue).emits(it()..equals(0));
      });
      test('does not consume an error', () async {
        final queue = _countingStream(1, errorAt: 0);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmitMultiple(it()..equals(0)));
        await check(queue).emitsError<UnimplementedError>(
            it()..has((e) => e.message, 'message').equals('Error at 1'));
      });
    });

    group('isDone', () {
      test('succeeds for an empty stream', () async {
        await check(_countingStream(0)).isDone();
      });
      test('fails for a stream that emits a value', () async {
        await check(_countingStream(1)).isRejectedByAsync(it()..isDone(),
            actual: ['a stream'], which: ['emitted an unexpected value: <0>']);
      });
      test('fails for a stream that emits an error', () async {
        final controller = StreamController<void>();
        controller.addError('sad', StackTrace.fromString('fake trace'));
        await check(StreamQueue(controller.stream)).isRejectedByAsync(
            it()..isDone(),
            actual: ['a stream'],
            which: ['emitted an unexpected error: \'sad\'', 'fake trace']);
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync<StreamQueue<int>>(queue, it()..isDone());
        await check(queue).emits(it()..equals(0));
      });
      test('can be described', () async {
        await check(it<StreamQueue<int>>()..isDone())
            .hasAsyncDescriptionWhich(it()..deepEquals(['  is done']));
      });
    });

    group('emitsAnyOf', () {
      test('succeeds for a stream that matches one condition', () async {
        await check(_countingStream(1)).anyOf(
            [it()..emits(it()..equals(42)), it()..emits((it()..equals(0)))]);
      });
      test('fails for a stream that matches no conditions', () async {
        await check(_countingStream(0)).isRejectedByAsync(
            it()
              ..anyOf([
                it()..emits(),
                it()..emitsThrough(it()..equals(1)),
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
        await check(_countingStream(1)).isRejectedByAsync(
            it()
              ..anyOf([
                it()..emits(it()..equals(42)),
                it()..emitsThrough(it()..equals(10)),
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
        await check(
                it<StreamQueue<int>>()..anyOf([it()..emits(), it()..emits()]))
            .hasAsyncDescriptionWhich(
                it()..deepEquals(['  satisfies any of 2 conditions']));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync<StreamQueue<int>>(
            queue,
            it()
              ..anyOf([
                it()..emits(it()..equals(10)),
                it()..emitsThrough(it()..equals(42)),
              ]));
        await check(queue).emits(it()..equals(0));
      });
      test('consumes events', () async {
        final queue = _countingStream(3);
        await check(queue).anyOf([
          it()..emits(it()..equals(1)),
          it()..emitsThrough(it()..equals(1))
        ]);
        await check(queue).emits(it()..equals(2));
      });
    });
  });

  group('StreamQueueWrap', () {
    test('can wrap streams in a queue', () async {
      await check(Stream.value(1)).withQueue.emits();
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
