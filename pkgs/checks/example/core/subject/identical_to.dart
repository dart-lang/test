import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('identicalTo', () {
    final original = ['a', 'b'];
    final alias = original;
    final copy = ['a', 'b'];

    // This check succeeds.
    check(alias).identicalTo(original);

    // This check fails, the lists are equal but not identical.
    check(copy).identicalTo(original);
    // Expected: ['a', 'b']
    // Actual: ['a', 'b']
    // Which: is not identical
  });
}
