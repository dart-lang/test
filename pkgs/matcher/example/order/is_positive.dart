import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isPositive', () {
    // This check succeeds.
    expect(1, isPositive);

    // This check fails.
    expect(0, isPositive);
    // Expected: a positive value
    //   Actual: <0>
    //    Which: is not a positive value
  });
}
