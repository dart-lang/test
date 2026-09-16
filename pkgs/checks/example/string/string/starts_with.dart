import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('startsWith', () {
    // This check succeeds.
    check('package:checks').startsWith('package:');

    // This check fails.
    check('package:checks').startsWith('dart:');
    // Expected: a string starting with 'dart:'
    // Actual: 'package:checks'
    // Which: does not start with 'dart:'
  });
}
