import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotFinite', () {
    // This check succeeds.
    check(double.infinity).isNotFinite;

    // This check succeeds. NaN is not finite.
    check(double.nan).isNotFinite;

    // This check fails.
    check(1.5).isNotFinite;
    // Expected: a non-finite number
    // Actual: <1.5>
    // Which: is finite
  });
}
