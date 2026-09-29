import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('mayEmitMultiple', () async {
    // This check succeeds.
    await expectLater(
      Stream.fromIterable([1, 1, 2]),
      emitsInOrder([mayEmitMultiple(1), 2]),
    );

    // This check fails.
    await expectLater(
      Stream.fromIterable([1, 1, 2]),
      emitsInOrder([mayEmitMultiple(1), 1]),
    );
    // Expected: should do the following in order:
    //           • emit an event that <1> zero or more times
    //           • emit an event that <1>
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 1
    //                   • 2
    //                   x Stream closed.
    //             which didn't emit an event that <1>
  });
}
