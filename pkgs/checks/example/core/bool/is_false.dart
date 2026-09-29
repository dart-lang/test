import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isFalse', () {
    // This check succeeds.
    check('checks'.isEmpty).isFalse;

    // This check fails.
    check(''.isEmpty).isFalse;
    // Expected: false
    // Actual: <true>
  });
}
