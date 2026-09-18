import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emitsInAnyOrder', () async {
    // This check succeeds.
    await expectLater(
      Stream.fromIterable([1, 2, 3]),
      emitsInAnyOrder([3, 1, 2]),
    );

    // This check fails.
    await expectLater(
      Stream.fromIterable([1, 2, 3]),
      emitsInAnyOrder([3, 1, 9]),
    );
    // Expected: should do the following in any order:
    //           • emit an event that <3>
    //           • emit an event that <1>
    //           • emit an event that <9>
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 2
    //                   • 3
    //                   x Stream closed.
  });
}
