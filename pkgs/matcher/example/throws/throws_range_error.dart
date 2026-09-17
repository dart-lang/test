import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsRangeError', () {
    // This check succeeds.
    expect(() => throw RangeError.value(42), throwsRangeError);

    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsRangeError);
    // Expected: throws <Instance of 'RangeError'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
