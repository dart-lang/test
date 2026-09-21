import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emitsDone', () async {
    // This check succeeds.
    await expectLater(const Stream<int>.empty(), emitsDone);

    // This check fails.
    await expectLater(Stream.fromIterable([1, 2, 3]), emitsDone);
    // Expected: should be done
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 2
    //                   • 3
    //                   x Stream closed.
  });
}
