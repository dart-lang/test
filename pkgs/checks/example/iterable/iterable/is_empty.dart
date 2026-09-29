import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isEmpty', () {
    // This check succeeds.
    check(<String>[]).isEmpty;

    // This check fails.
    check(['apple', 'banana']).isEmpty;
    // Expected: an empty iterable
    // Actual: ['apple', 'banana']
    // Which: is not empty
  });
}
