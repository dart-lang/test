import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('inOrder', () async {
    // This check succeeds.
    await check(Stream.fromIterable(['first', 'second'])).withQueue.inOrder([
      .it()..emits(.it()..equals('first')),
      .it()..emits(.it()..equals('second')),
    ]);

    // This check fails because the second condition is not satisfied.
    await check(Stream.fromIterable(['first', 'second'])).withQueue.inOrder([
      .it()..emits(.it()..equals('first')),
      .it()..emits(.it()..equals('third')),
    ]);
    // Expected: a Stream<String> that:
    //     emits a value that:
    //       equals 'first'
    //     emits a value that:
    //       equals 'third'
    // Actual: a stream
    // Which: satisfied 1 conditions then
    // failed to satisfy the condition at index 1
    // because it:
    //   Expected: emits 'third'
    //   Actual: emits 'second'
    //   Which: differs at offset 0:
    //     third
    //     second
    //     ^
  });
}
