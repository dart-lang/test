import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('greaterThan', () {
    // This check succeeds.
    expect(42, greaterThan(10));

    // This check fails.
    expect(7, greaterThan(10));
    // Expected: a value greater than <10>
    //   Actual: <7>
    //    Which: is not a value greater than <10>
  });
}
