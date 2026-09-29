import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isFinite', () {
    check(1.5).isFinite;
  });

  test('isFinite on an infinite number', () {
    check(double.infinity).isFinite;
    // Expected: a finite number
    // Actual: <Infinity>
    // Which: is not finite
  });

  test('isFinite on NaN, which is not finite', () {
    check(double.nan).isFinite;
    // Expected: a finite number
    // Actual: <NaN>
    // Which: is not finite
  });
}
