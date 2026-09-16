import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('contains', () {
    // This check succeeds.
    check([1, 2, 3]).contains(2);

    // This check fails.
    check([1, 2, 3]).contains(4);
    // Expected: an iterable containing <4>
    // Actual: [1, 2, 3]
    // Which: does not contain <4>
  });
}
