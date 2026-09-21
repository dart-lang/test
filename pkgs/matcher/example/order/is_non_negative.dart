import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNonNegative', () {
    // This check succeeds.
    expect(0, isNonNegative);

    // This check fails.
    expect(-1, isNonNegative);
    // Expected: a non-negative value
    //   Actual: <-1>
    //    Which: is not a non-negative value
  });
}
