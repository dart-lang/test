import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('inClosedOpenRange', () {
    // This check succeeds.
    expect(1, inClosedOpenRange(1, 10));

    // This check fails.
    expect(10, inClosedOpenRange(1, 10));
    // Expected: be in range from 1 (inclusive) to 10 (exclusive)
    //   Actual: <10>
  });
}
