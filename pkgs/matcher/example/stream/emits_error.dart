import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emitsError', () async {
    // This check succeeds.
    await expectLater(
      Stream<int>.error(StateError('nope')),
      emitsError(isStateError),
    );

    // This check fails.
    await expectLater(Stream.fromIterable([1, 2, 3]), emitsError(isStateError));
    // Expected: should emit an error that <Instance of 'StateError'>
    //   Actual: <Instance of '_MultiStream<int>'>
    //    Which: emitted • 1
    //                   • 2
    //                   • 3
    //                   x Stream closed.
    //             which emitted <1>
  });
}
