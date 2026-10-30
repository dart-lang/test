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
    // Actual: a stream that emitted <1>
    // Which: emitted a value before closing
  });

  test('isDone when the stream emits an error', () async {
    await check(Stream<int>.error(StateError('nope'))).withQueue.isDone;
    // Expected: a Stream<int> that:
    //   is done
    // Actual: a stream that emitted error <Bad state: nope>
    // Which: emitted an error before closing at:
  });
}
