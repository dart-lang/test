import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotNegative', () {
    check(0).isNotNegative;
  });

  test('isNotNegative on a negative number', () {
    check(-1).isNotNegative;
    // Expected: a non-negative number
    // Actual: <-1>
    // Which: is negative
  });

  test('isNotNegative on negative zero, which is negative', () {
    check(-0.0).isNotNegative;
    // Expected: a non-negative number
    // Actual: <-0.0>
    // Which: is negative
  });
}
