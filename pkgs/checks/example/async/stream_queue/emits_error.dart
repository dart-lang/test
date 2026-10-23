import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emitsError', () async {
    await check(
      Stream<int>.error(StateError('nope')),
    ).withQueue.emitsError<StateError>(
      .it()..has('message', (e) => e.message).equals('nope'),
    );
  });

  test('emitsError when the stream emits a value', () async {
    await check(Stream.fromIterable([1, 2, 3])).withQueue.emitsError();
    // Expected: a Stream<int> that:
    //   emits an error
    // Actual: a stream emitting value <1>
    // Which: closed without emitting an error
  });

  test('emitsError when the error has a different type', () async {
    await check(
      Stream<int>.error(StateError('nope')),
    ).withQueue.emitsError<ArgumentError>();
    // Expected: a Stream<int> that:
    //   emits an error of type ArgumentError
    // Actual: a stream with error <Bad state: nope>
    // Which: emitted an error which is not ArgumentError at:
  });
}
