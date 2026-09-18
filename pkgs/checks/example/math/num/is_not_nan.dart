import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotNaN', () {
    // This check succeeds.
    check(1.5).isNotNaN;

    // This check fails.
    check(double.nan).isNotNaN;
    // Expected: a number (not NaN)
    // Actual: <NaN>
  });
}
