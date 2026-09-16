import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('anyOf', () async {
    // This check succeeds, the second condition is satisfied.
    await check(Stream.fromIterable(['ready'])).withQueue.anyOf([
      .it()..emits(.it()..equals('starting')),
      .it()..emits(.it()..equals('ready')),
    ]);

    // This check fails because no condition is satisfied.
    await check(
      Stream.fromIterable(['ready']),
    ).withQueue.anyOf([.it()..emits(.it()..equals('starting')), .it()..isDone]);
    // Expected: a Stream<String> that:
    //   satisfies one of:
    //     emits a value that:
    //       equals 'starting'
    //   or,
    //     is done
    // Actual: a stream
    // Which: failed to satisfy any condition
    // failed the condition at index 0 because it:
    //   Expected: emits 'starting'
    //   Actual: emits 'ready'
    //   Which: differs at offset 0:
    //     starting
    //     ready
    //     ^
    // failed the condition at index 1 because it:
    //   emitted an unexpected value: 'ready'
  });
}
