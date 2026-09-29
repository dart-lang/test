import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isTrue', () {
    // This check succeeds.
    check('checks'.isNotEmpty).isTrue;

    // This check fails.
    check(''.isNotEmpty).isTrue;
    // Expected: true
    // Actual: <false>
  });
}
