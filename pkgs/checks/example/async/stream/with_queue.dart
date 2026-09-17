import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('withQueue', () async {
    // This check succeeds. Wrapping the stream in a queue makes the stream
    // expectations available.
    await check(Stream.fromIterable([1, 2])).withQueue.inOrder([
      .it()..emits(.it()..equals(1)),
      .it()..emits(.it()..equals(2)),
      .it()..isDone,
    ]);

    // This check fails. The queue is at the same level as the stream subject,
    // so the failure is described in terms of the stream.
    await check(Stream.fromIterable([1, 2])).withQueue.isDone;
    // Expected: a Stream<int> that:
    //   is done
    // Actual: a stream
    // Which: emitted an unexpected value: <1>
  });
}
