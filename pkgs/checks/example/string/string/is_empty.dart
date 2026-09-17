import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isEmpty', () {
    // This check succeeds.
    check('').isEmpty;

    // This check fails.
    check('not empty').isEmpty;
    // Expected: an empty string
    // Actual: 'not empty'
    // Which: is not empty
  });
}
