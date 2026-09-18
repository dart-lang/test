import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsValue', () {
    final scores = {'alice': 90, 'bob': 85};

    // This check succeeds.
    check(scores).containsValue(85);

    // This check fails.
    check(scores).containsValue(100);
    // Expected: a map with value <100>
    // Actual: {'alice': 90, 'bob': 85}
    // Which: does not contain value <100>
  });
}
