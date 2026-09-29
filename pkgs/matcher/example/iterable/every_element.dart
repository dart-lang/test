import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('everyElement', () {
    // This check succeeds.
    expect([2, 4, 6], everyElement(greaterThan(0)));

    // This check fails.
    expect([2, -4, 6], everyElement(greaterThan(0)));
    // Expected: every element(a value greater than <0>)
    //   Actual: [2, -4, 6]
    //    Which: has value <-4> which is not a value greater than <0> at index 1
  });
}
