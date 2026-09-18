import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('length', () {
    // This check succeeds.
    check('hello').length.equals(5);

    // This check fails.
    check('hello').length.isGreaterThan(10);
    // Expected: a String that has length: a value > <10>
    // Actual: a String that has length: <5>
    // Which: is not greater than <10>
  });
}
