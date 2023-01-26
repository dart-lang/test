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
        await checkThat(_futureSuccess()).completes().which(it()..equals(42));
      });
      test('rejects futures which complete as errors', () async {
        await checkThat(_futureFail()).isRejectedByAsync(
          it()..completes().which(it()..equals(1)),
          actual: ['a future that completes as an error'],
          which: ['threw <UnimplementedError>'],
        );
      });
      test('can be described', () async {
        await checkThat(it<Future<void>>()..completes())
            .asyncDescription
            .which(it()..deepEquals(['  completes to a value']));
        await checkThat(it<Future<void>>()..completes().which(it()..equals(42)))
            .asyncDescription
            .which(it()
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
        await checkThat(_futureFail())
            .throws<UnimplementedError>()
            .which(it()..has((p0) => p0.message, 'message').isNull());
      });
      test('fails for futures that complete to a value', () async {
        await checkThat(_futureSuccess()).isRejectedByAsync(
          it()..throws(),
          actual: ['completed to <42>'],
          which: ['did not throw'],
        );
      });
      test('failes for futures that complete to an error of the wrong type',
          () async {
        await checkThat(_futureFail()).isRejectedByAsync(
          it()..throws<StateError>(),
          actual: ['completed to error <UnimplementedError>'],
          which: ['is not an StateError'],
        );
      });
      test('can be described', () async {
        await checkThat(it<Future<void>>()..throws())
            .asyncDescription
            .which(it()..deepEquals(['  completes to an error']));
        await checkThat(it<Future<void>>()..throws<StateError>())
            .asyncDescription
            .which(it()
              ..deepEquals(['  completes to an error of type StateError']));
      });
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
  does not complete
Actual: a future that completed to 'value\'''');
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
  does not complete
Actual: a future that completed as an error:
Which: threw 'error'
fake trace''');
      });
      test('can be described', () async {
        await checkThat(it<Future<void>>()..doesNotComplete())
            .asyncDescription
            .which(it()..deepEquals(['  does not complete']));
      });
    });
  });

  group('StreamChecks', () {
    group('emits', () {
      test('succeeds for a stream that emits a value', () async {
        await checkThat(_countingStream(5)).emits().which(it()..equals(0));
      });
      test('fails for a stream that closes without emitting', () async {
        await checkThat(_countingStream(0)).isRejectedByAsync(
          it()..emits(),
          actual: ['a stream'],
          which: ['closed without emitting enough values'],
        );
      });
      test('fails for a stream that emits an error', () async {
        await checkThat(_countingStream(1, errorAt: 0)).isRejectedByAsync(
          it()..emits(),
          actual: ['a stream with error <UnimplementedError: Error at 1>'],
          which: ['emitted an error instead of a value'],
        );
      });
      test('can be described', () async {
        await checkThat(it<StreamQueue<void>>()..emits())
            .asyncDescription
            .which(it()..deepEquals(['  emits a value']));
        await checkThat(it<StreamQueue<int>>()..emits().which(it()..equals(42)))
            .asyncDescription
            .which(it()
              ..deepEquals([
                '  emits a value that:',
                '    equals <42>',
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1, errorAt: 0);
        await softCheckAsync<StreamQueue<int>>(queue, it()..emits());
        await checkThat(queue).emitsError();
      });
    });

    group('emitsError', () {
      test('succeeds for a stream that emits an error', () async {
        await checkThat(_countingStream(1, errorAt: 0))
            .emitsError<UnimplementedError>();
      });
      test('fails for a stream that closes without emitting an error',
          () async {
        await checkThat(_countingStream(0)).isRejectedByAsync(
          it()..emitsError(),
          actual: ['a stream'],
          which: ['closed without emitting an expected error'],
        );
      });
      test('fails for a stream that emits value', () async {
        await checkThat(_countingStream(1)).isRejectedByAsync(
          it()..emitsError(),
          actual: ['a stream emitting value <0>'],
          which: ['closed without emitting an error'],
        );
      });
      test('fails for a stream that emits an error of the incorrect type',
          () async {
        await checkThat(_countingStream(1, errorAt: 0)).isRejectedByAsync(
          it()..emitsError<StateError>(),
          actual: ['a stream with error <UnimplementedError: Error at 1>'],
          which: ['emitted an error with an incorrect type, is not StateError'],
        );
      });
      test('can be described', () async {
        await checkThat(it<StreamQueue<void>>()..emitsError())
            .asyncDescription
            .which(it()..deepEquals(['  emits an error']));
        await checkThat(it<StreamQueue<void>>()..emitsError<StateError>())
            .asyncDescription
            .which(it()..deepEquals(['  emits an error of type StateError']));
        await checkThat(it<StreamQueue<void>>()
              ..emitsError<StateError>()
                  .which(it()..has((e) => e.message, 'message').equals('foo')))
            .asyncDescription
            .which(it()
              ..deepEquals([
                '  emits an error of type StateError that:',
                '    has message that:',
                '      equals \'foo\''
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync<StreamQueue<int>>(queue, it()..emitsError());
        await checkThat(queue).emits().which((it()..equals(0)));
      });
    });

    group('emitsThrough', () {
      test('succeeds for a stream that eventuall emits a matching value',
          () async {
        await checkThat(_countingStream(5)).emitsThrough(it()..equals(4));
      });
      test('fails for a stream that closes without emitting a matching value',
          () async {
        await checkThat(_countingStream(4)).isRejectedByAsync(
          it()..emitsThrough(it()..equals(5)),
          actual: ['a stream'],
          which: ['ended after emitting 4 elements with none matching'],
        );
      });
      test('can be described', () async {
        await checkThat(it<StreamQueue<int>>()..emitsThrough(it()..equals(42)))
            .asyncDescription
            .which(it()
              ..deepEquals([
                '  emits any values then emits a value that:',
                '    equals <42>'
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync(
            queue, it<StreamQueue<int>>()..emitsThrough(it()..equals(42)));
        checkThat(queue).emits().which(it()..equals(0));
      });
      test('consumes events', () async {
        final queue = _countingStream(3);
        await checkThat(queue).emitsThrough(it()..equals(1));
        await checkThat(queue).emits().which((it()..equals(2)));
      });
    });

    group('emitsInOrder', () {
      test('succeeds for happy case', () async {
        await checkThat(_countingStream(2)).inOrder([
          it()..emits().which(it()..equals(0)),
          it()..emits().which((it()..equals(1))),
          it()..isDone(),
        ]);
      });
      test('reports which condition failed', () async {
        await checkThat(_countingStream(1)).isRejectedByAsync(
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
        await checkThat(_countingStream(2)).isRejectedByAsync(
          it()..inOrder([it()..emits(), it()..emits().which(it()..equals(2))]),
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
        await checkThat(it<StreamQueue<int>>()..inOrder([it(), it()]))
            .asyncDescription
            .which(it()..deepEquals(['  satisfies 2 conditions in order']));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(3);
        await softCheckAsync<StreamQueue<int>>(
            queue,
            it()
              ..inOrder([
                it()..emits().which(it()..equals(0)),
                it()..emits().which(it()..equals(1)),
                it()..emits().which(it()..equals(42)),
              ]));
        await checkThat(queue).inOrder([
          it()..emits().which(it()..equals(0)),
          it()..emits().which(it()..equals(1)),
          it()..emits().which(it()..equals(2)),
          it()..isDone(),
        ]);
      });
      test('consumes events', () async {
        final queue = _countingStream(3);
        await checkThat(queue).inOrder([it()..emits(), it()..emits()]);
        await checkThat(queue).emits().which(it()..equals(2));
      });
    });

    group('neverEmits', () {
      test(
          'succeeds for a stream that closes without emitting a matching value',
          () async {
        await checkThat(_countingStream(5)).neverEmits(it()..equals(5));
      });
      test('fails for a stream that emits a matching value', () async {
        await checkThat(_countingStream(6)).isRejectedByAsync(
          it()..neverEmits(it()..equals(5)),
          actual: ['a stream'],
          which: ['emitted <5>', 'following 5 other items'],
        );
      });
      test('can be described', () async {
        await checkThat(it<StreamQueue<int>>()..neverEmits(it()..equals(42)))
            .asyncDescription
            .which(it()
              ..deepEquals([
                '  never emits a value that:',
                '    equals <42>',
              ]));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..neverEmits(it()..equals(1)));
        await checkThat(queue).inOrder([
          it()..emits().which(it()..equals(0)),
          it()..emits().which(it()..equals(1)),
          it()..isDone(),
        ]);
      });
    });

    group('mayEmit', () {
      test('succeeds for a stream that emits a matching value', () async {
        await checkThat(_countingStream(1)).mayEmit(it()..equals(0));
      });
      test('succeeds for a stream that emits an error', () async {
        await checkThat(_countingStream(1, errorAt: 0))
            .mayEmit(it()..equals(0));
      });
      test('succeeds for a stream that closes', () async {
        await checkThat(_countingStream(0)).mayEmit(it()..equals(42));
      });
      test('consumes a matching event', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmit(it()..equals(0)));
        await checkThat(queue).emits().which(it()..equals(1));
      });
      test('does not consume a non-matching event', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmit(it()..equals(1)));
        await checkThat(queue).emits().which(it()..equals(0));
      });
      test('does not consume an error', () async {
        final queue = _countingStream(1, errorAt: 0);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmit(it()..equals(0)));
        await checkThat(queue)
            .emitsError<UnimplementedError>()
            .which(it()..has((e) => e.message, 'message').equals('Error at 1'));
      });
    });

    group('mayEmitMultiple', () {
      test('succeeds for a stream that emits a matching value', () async {
        await checkThat(_countingStream(1)).mayEmitMultiple(it()..equals(0));
      });
      test('succeeds for a stream that emits an error', () async {
        await checkThat(_countingStream(1, errorAt: 0))
            .mayEmitMultiple(it()..equals(0));
      });
      test('succeeds for a stream that closes', () async {
        await checkThat(_countingStream(0)).mayEmitMultiple(it()..equals(42));
      });
      test('consumes matching events', () async {
        final queue = _countingStream(3);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmitMultiple(it()..isLessThan(2)));
        await checkThat(queue).emits().which(it()..equals(2));
      });
      test('consumes no events if no events match', () async {
        final queue = _countingStream(2);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmitMultiple(it()..isLessThan(0)));
        await checkThat(queue).emits().which(it()..equals(0));
      });
      test('does not consume an error', () async {
        final queue = _countingStream(1, errorAt: 0);
        await softCheckAsync<StreamQueue<int>>(
            queue, it()..mayEmitMultiple(it()..equals(0)));
        await checkThat(queue)
            .emitsError<UnimplementedError>()
            .which(it()..has((e) => e.message, 'message').equals('Error at 1'));
      });
    });

    group('isDone', () {
      test('succeeds for an empty stream', () async {
        await checkThat(_countingStream(0)).isDone();
      });
      test('fails for a stream that emits a value', () async {
        await checkThat(_countingStream(1)).isRejectedByAsync(it()..isDone(),
            actual: ['a stream'], which: ['emitted an unexpected value: <0>']);
      });
      test('fails for a stream that emits an error', () async {
        final controller = StreamController<void>();
        controller.addError('sad', StackTrace.fromString('fake trace'));
        await checkThat(StreamQueue(controller.stream)).isRejectedByAsync(
            it()..isDone(),
            actual: ['a stream'],
            which: ['emitted an unexpected error: \'sad\'', 'fake trace']);
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync<StreamQueue<int>>(queue, it()..isDone());
        await checkThat(queue).emits().which(it()..equals(0));
      });
      test('can be described', () async {
        await checkThat(it<StreamQueue<int>>()..isDone())
            .asyncDescription
            .which(it()..deepEquals(['  is done']));
      });
    });

    group('emitsAnyOf', () {
      test('succeeds for a stream that matches one condition', () async {
        await checkThat(_countingStream(1)).anyOf([
          it()..emits().which(it()..equals(42)),
          it()..emits().which((it()..equals(0)))
        ]);
      });
      test('fails for a stream that matches no conditions', () async {
        await checkThat(_countingStream(0)).isRejectedByAsync(
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
        await checkThat(_countingStream(1)).isRejectedByAsync(
            it()
              ..anyOf([
                it()..emits().which(it()..equals(42)),
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
        await checkThat(
                it<StreamQueue<int>>()..anyOf([it()..emits(), it()..emits()]))
            .asyncDescription
            .which(it()..deepEquals(['  satisfies any of 2 conditions']));
      });
      test('uses a transaction', () async {
        final queue = _countingStream(1);
        await softCheckAsync<StreamQueue<int>>(
            queue,
            it()
              ..anyOf([
                it()..emits().which(it()..equals(10)),
                it()..emitsThrough(it()..equals(42)),
              ]));
        await checkThat(queue).emits().which(it()..equals(0));
      });
      test('consumes events', () async {
        final queue = _countingStream(3);
        await checkThat(queue).anyOf([
          it()..emits().which(it()..equals(1)),
          it()..emitsThrough(it()..equals(1))
        ]);
        await checkThat(queue).emits().which(it()..equals(2));
      });
    });
  });

  group('ChainAsync', () {
    test('which', () async {
      await checkThat(_futureSuccess()).completes().which(it()..equals(42));
    });
  });

  group('StreamQueueWrap', () {
    test('can wrap streams in a queue', () async {
      await checkThat(Stream.value(1)).withQueue.emits();
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
