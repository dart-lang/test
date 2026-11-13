import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('has', () {
    // This check succeeds.
    check(RegExp('^abc')).has('pattern', (r) => r.pattern).equals('^abc');

    // This check fails.
    check(RegExp('^abc')).has('pattern', (r) => r.pattern).equals('^xyz');
    // Expected: a RegExp that has pattern: '^xyz'
    // Actual: a RegExp that has pattern: '^abc'
    // Which: differs at offset 1:
    //   ^xyz
    //   ^abc
    //    ^
  });
}
