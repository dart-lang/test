import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('mayEmit', () async {
    // This check succeeds, the optional event is simply not consumed.
    await expectLater(
      Stream.fromIterable([1, 2, 3]),
      emitsInOrder([mayEmit(9), 1, 2, 3]),
    );

    // This check fails, `mayEmit` consumed the 1 that came after it.
    await expectLater(
      Stream.fromIterable([1, 2, 3]),
      emitsInOrder([mayEmit(1), 1, 2, 3]),
    );
    // Expected: should do the following in order:
    //           • maybe emit an event that <1>
    //           • emit an event that <1>
    //           • emit an event that <2>
    //           • emit an event that <3>
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 2
    //                   • 3
    //                   x Stream closed.
    //             which didn't emit an event that <1>
  });
}
