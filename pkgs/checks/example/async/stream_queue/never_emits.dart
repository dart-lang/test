import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('neverEmits', () async {
    // This check succeeds, the stream closes without emitting a negative
    // value.
    await check(
      Stream.fromIterable([1, 2, 3]),
    ).withQueue.neverEmits(.it()..isLessThan(0));

    // This check fails because the stream emits a negative value.
    await check(
      Stream.fromIterable([1, 2, -3]),
    ).withQueue.neverEmits(.it()..isLessThan(0));
    // Expected: a Stream<int> that:
    //   never emits a value that:
    //     is less than <0>
    // Actual: a stream
    // Which: emitted <-3>
    // following 2 other items
  });
}
