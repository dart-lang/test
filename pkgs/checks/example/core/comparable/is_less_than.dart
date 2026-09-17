import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isLessThan', () {
    // This check succeeds.
    check('apple').isLessThan('banana');

    // This check fails.
    check('banana').isLessThan('apple');
    // Expected: a value < 'apple'
    // Actual: 'banana'
    // Which: is not less than 'apple'
  });
}
