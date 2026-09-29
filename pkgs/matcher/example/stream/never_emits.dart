import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('neverEmits', () async {
    // This check succeeds.
    await expectLater(Stream.fromIterable([1, 2, 3]), neverEmits(9));

    // This check fails.
    await expectLater(Stream.fromIterable([1, 2, 3]), neverEmits(3));
    // Expected: should never emit an event that <3>
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 2
    //                   • 3
    //                   x Stream closed.
    //             which after 2 events did emit an event that <3>
  });
}
