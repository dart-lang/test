import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsConcurrentModificationError', () {
    // This check succeeds.
    expect(
      () => Error.throwWithStackTrace(
        ConcurrentModificationError([1, 2, 3]),
        StackTrace.empty,
      ),
      throwsConcurrentModificationError,
    );

    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsConcurrentModificationError);
    // Expected: throws <Instance of 'ConcurrentModificationError'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
