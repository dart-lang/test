import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('anyOf', () {
    // This check succeeds.
    expect(42, anyOf(lessThan(10), greaterThan(40)));

    // This check fails.
    expect(42, anyOf(lessThan(10), greaterThan(100)));
    // Expected: (a value less than <10> or a value greater than <100>)
    //   Actual: <42>
  });
}
