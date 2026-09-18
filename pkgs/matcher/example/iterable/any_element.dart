import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('anyElement', () {
    // This check succeeds.
    expect([1, 2, 3], anyElement(greaterThan(2)));

    // This check fails.
    expect([1, 2, 3], anyElement(greaterThan(5)));
    // Expected: some element a value greater than <5>
    //   Actual: [1, 2, 3]
  });
}
