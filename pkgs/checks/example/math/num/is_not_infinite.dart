import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotInfinite', () {
    // This check succeeds.
    check(1.5).isNotInfinite;

    // This check succeeds. NaN is not infinite.
    check(double.nan).isNotInfinite;

    // This check fails.
    check(double.negativeInfinity).isNotInfinite;
    // Expected: a non-infinite number
    // Actual: <-Infinity>
    // Which: is infinite
  });
}
