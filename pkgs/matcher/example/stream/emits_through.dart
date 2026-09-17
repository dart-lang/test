import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emitsThrough', () async {
    // This check succeeds.
    await expectLater(Stream.fromIterable([1, 2, 3]), emitsThrough(3));

    // This check fails.
    await expectLater(Stream.fromIterable([1, 2, 3]), emitsThrough(9));
    // Expected: should eventually emit an event that <9>
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 2
    //                   • 3
    //                   x Stream closed.
    //             which never did emit an event that <9>
  });
}
