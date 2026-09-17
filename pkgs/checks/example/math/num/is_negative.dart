import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNegative', () {
    // This check succeeds.
    check(-1).isNegative;

    // This check succeeds. Negative zero is negative.
    check(-0.0).isNegative;

    // This check fails.
    check(0).isNegative;
    // Expected: a negative number
    // Actual: <0>
    // Which: is not negative
  });
}
