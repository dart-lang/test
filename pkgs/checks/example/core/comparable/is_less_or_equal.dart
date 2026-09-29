import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isLessOrEqual', () {
    // This check succeeds.
    check('banana').isLessOrEqual('banana');

    // This check fails.
    check('banana').isLessOrEqual('apple');
    // Expected: a value <= 'apple'
    // Actual: 'banana'
    // Which: is not less than or equal to 'apple'
  });
}
