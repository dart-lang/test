import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isGreaterOrEqual', () {
    // This check succeeds.
    check('apple').isGreaterOrEqual('apple');

    // This check fails.
    check('apple').isGreaterOrEqual('banana');
    // Expected: a value >= 'banana'
    // Actual: 'apple'
    // Which: is not greater than or equal to 'banana'
  });
}
