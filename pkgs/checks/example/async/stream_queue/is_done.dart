import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isDone', () async {
    await check(const Stream<int>.empty()).withQueue.isDone;
  });

  test('isDone when the stream emits a value', () async {
    await check(Stream.fromIterable([1, 2, 3])).withQueue.isDone;
    // Expected: a Stream<int> that:
    //   is done
    // Actual: a stream
    // Which: emitted an unexpected value: <1>
  });

  test('isDone when the stream emits an error', () async {
    await check(Stream<int>.error(StateError('nope'))).withQueue.isDone;
    // Expected: a Stream<int> that:
    //   is done
    // Actual: a stream
    // Which: emitted an unexpected error: <Bad state: nope> at:
  });
}
