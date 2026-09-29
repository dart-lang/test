import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotEmpty', () {
    // This check succeeds.
    check(['apple', 'banana']).isNotEmpty;

    // This check fails.
    check(<String>[]).isNotEmpty;
    // Expected: a non-empty iterable
    // Actual: []
    // Which: is empty
  });
}
