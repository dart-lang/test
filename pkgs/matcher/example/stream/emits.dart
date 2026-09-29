import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emits', () async {
    // This check succeeds.
    await expectLater(Stream.fromIterable([1, 2, 3]), emits(1));

    // This check fails.
    await expectLater(Stream.fromIterable([1, 2, 3]), emits(2));
    // Expected: should emit an event that <2>
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 2
    //                   • 3
    //                   x Stream closed.
  });
}
