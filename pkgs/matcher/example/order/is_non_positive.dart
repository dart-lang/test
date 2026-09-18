import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNonPositive', () {
    // This check succeeds.
    expect(0, isNonPositive);

    // This check fails.
    expect(1, isNonPositive);
    // Expected: a non-positive value
    //   Actual: <1>
    //    Which: is not a non-positive value
  });
}
