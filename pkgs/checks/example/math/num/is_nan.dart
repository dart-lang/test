import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNaN', () {
    // This check succeeds.
    check(double.nan).isNaN;

    // This check fails.
    check(1.5).isNaN;
    // Expected: NaN
    // Actual: <1.5>
  });
}
