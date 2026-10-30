import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emits', () async {
    await check(
      Stream.fromIterable([1, 2, 3]),
    ).withQueue.emits(.it()..equals(1));
  });

  test('emits on a stream that closes without emitting a value', () async {
    await check(const Stream<int>.empty()).withQueue.emits();
    // Expected: a Stream<int> that:
    //   emits a value
    // Actual: a stream that closed
    // Which: did not emit a value
  });

  test('emits on a stream that emits an error', () async {
    await check(Stream<int>.error(StateError('nope'))).withQueue.emits();
    // Expected: a Stream<int> that:
    //   emits a value
    // Actual: a stream that emitted error <Bad state: nope>
    // Which: emitted an error instead of a value at:
  });
}
