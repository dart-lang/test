import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('lessThan', () {
    // This check succeeds.
    expect(7, lessThan(10));

    // This check fails.
    expect(42, lessThan(10));
    // Expected: a value less than <10>
    //   Actual: <42>
    //    Which: is not a value less than <10>
  });
}
