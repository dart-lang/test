import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emitsAnyOf', () async {
    // This check succeeds.
    await expectLater(Stream.fromIterable([1, 2, 3]), emitsAnyOf([0, 1]));

    // This check fails.
    await expectLater(Stream.fromIterable([1, 2, 3]), emitsAnyOf([0, 9]));
    // Expected: should do one of the following:
    //           • emit an event that <0>
    //           • emit an event that <9>
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 2
    //                   • 3
    //                   x Stream closed.
    //             which failed all options:
    //                   • failed to emit an event that <0>
    //                   • failed to emit an event that <9>
  });
}
