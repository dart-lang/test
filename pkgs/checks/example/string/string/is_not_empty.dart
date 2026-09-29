import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotEmpty', () {
    // This check succeeds.
    check('some content').isNotEmpty;

    // This check fails.
    check('').isNotEmpty;
    // Expected: a non-empty string
    // Actual: ''
    // Which: is empty
  });
}
