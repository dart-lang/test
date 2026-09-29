import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isGreaterThan', () {
    // This check succeeds.
    check('banana').isGreaterThan('apple');

    // This check fails.
    check('apple').isGreaterThan('banana');
    // Expected: a value > 'banana'
    // Actual: 'apple'
    // Which: is not greater than 'banana'
  });
}
