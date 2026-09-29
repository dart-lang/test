import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotEmpty', () {
    // This check succeeds.
    check({'alice': 90, 'bob': 85}).isNotEmpty;

    // This check fails.
    check(<String, int>{}).isNotEmpty;
    // Expected: a non-empty map
    // Actual: {}
    // Which: is empty
  });
}
