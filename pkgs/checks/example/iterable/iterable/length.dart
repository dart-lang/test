import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('length', () {
    // This check succeeds.
    check(['apple', 'banana', 'cherry']).length.equals(3);

    // This check fails.
    check(['apple', 'banana', 'cherry']).length.isLessThan(3);
    // Expected: a List<String> that has length: a value < <3>
    // Actual: a List<String> that has length: <3>
    // Which: is not less than <3>
  });
}
