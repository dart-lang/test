import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('any', () {
    // This check succeeds.
    check([1, 3, 5, 8]).any(.it()..isGreaterThan(7));

    // This check fails.
    check([1, 3, 5, 7]).any(.it()..isGreaterThan(7));
    // Expected: an iterable containing a value that is greater than <7>
    // Actual: [1, 3, 5, 7]
    // Which: contains no matching element
  });
}
