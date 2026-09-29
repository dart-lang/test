import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('matchesPattern', () {
    // This check succeeds.
    check('version 3.11.0').matchesPattern(RegExp(r'\d+\.\d+\.\d+'));

    // This check fails.
    check('version unknown').matchesPattern(RegExp(r'\d+\.\d+\.\d+'));
    // Expected: a string matching <RegExp: pattern=\d+\.\d+\.\d+ flags=>
    // Actual: 'version unknown'
    // Which: does not match <RegExp: pattern=\d+\.\d+\.\d+ flags=>
  });
}
