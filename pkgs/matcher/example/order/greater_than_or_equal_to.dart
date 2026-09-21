import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('greaterThanOrEqualTo', () {
    // This check succeeds.
    expect(10, greaterThanOrEqualTo(10));

    // This check fails.
    expect(9, greaterThanOrEqualTo(10));
    // Expected: a value greater than or equal to <10>
    //   Actual: <9>
    //    Which: is not a value greater than or equal to <10>
  });
}
