import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isInfinite', () {
    // This check succeeds.
    check(double.infinity).isInfinite;

    // This check succeeds.
    check(double.negativeInfinity).isInfinite;

    // This check fails. NaN is not infinite.
    check(double.nan).isInfinite;
    // Expected: an infinite number
    // Actual: <NaN>
    // Which: is not infinite
  });
}
