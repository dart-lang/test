import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('values', () {
    final scores = {'alice': 90, 'bob': 85};

    // This check succeeds.
    check(scores).values.contains(90);

    // This check fails.
    check(scores).values.contains(100);
    // Expected: a Map<String, int> that has values: an iterable containing <100>
    // Actual: a Map<String, int> that has values: (90, 85)
    // Which: does not contain <100>
  });
}
