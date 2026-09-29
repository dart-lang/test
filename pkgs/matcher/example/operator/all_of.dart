import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('allOf', () {
    // This check succeeds.
    expect(42, allOf(greaterThan(10), lessThan(100)));

    // This check fails.
    expect(42, allOf(greaterThan(10), lessThan(20)));
    // Expected: (a value greater than <10> and a value less than <20>)
    //   Actual: <42>
    //    Which: is not a value less than <20>
  });
}
