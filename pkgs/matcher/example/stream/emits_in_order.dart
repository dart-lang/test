import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emitsInOrder', () async {
    // This check succeeds.
    await expectLater(
      Stream.fromIterable([1, 2, 3]),
      emitsInOrder([1, 2, 3, emitsDone]),
    );

    // This check fails.
    await expectLater(
      Stream.fromIterable([1, 2, 3]),
      emitsInOrder([1, 3, emitsDone]),
    );
    // Expected: should do the following in order:
    //           • emit an event that <1>
    //           • emit an event that <3>
    //           • be done
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 2
    //                   • 3
    //                   x Stream closed.
    //             which didn't emit an event that <3>
  });
}
