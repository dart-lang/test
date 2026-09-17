import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsStateError', () {
    // This check succeeds.
    expect(() => throw StateError('nope'), throwsStateError);

    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsStateError);
    // Expected: throws <Instance of 'StateError'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
