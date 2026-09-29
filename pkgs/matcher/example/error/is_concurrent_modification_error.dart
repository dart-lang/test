import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isConcurrentModificationError', () {
    // This check succeeds.
    expect(
      ConcurrentModificationError([1, 2, 3]),
      isConcurrentModificationError,
    );

    // This check fails.
    expect(StateError('nope'), isConcurrentModificationError);
    // Expected: <Instance of 'ConcurrentModificationError'>
    //   Actual: StateError:<Bad state: nope>
    //    Which: is not an instance of 'ConcurrentModificationError'
  });
}
