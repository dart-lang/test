import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('contains', () {
    // This check succeeds.
    check('Hello, World!').contains('World');

    // This check succeeds.
    check('Hello, World!').contains(RegExp(r'\w+, \w+'));

    // This check fails.
    check('Hello, World!').contains('Goodbye');
    // Expected: a string that contains 'Goodbye'
    // Actual: 'Hello, World!'
    // Which: does not contain 'Goodbye'
  });
}
