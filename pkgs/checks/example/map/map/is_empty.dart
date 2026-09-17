import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isEmpty', () {
    // This check succeeds.
    check(<String, int>{}).isEmpty;

    // This check fails.
    check({'alice': 90, 'bob': 85}).isEmpty;
    // Expected: an empty map
    // Actual: {'alice': 90, 'bob': 85}
    // Which: is not empty
  });
}
