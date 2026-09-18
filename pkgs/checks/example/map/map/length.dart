import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('length', () {
    final scores = {'alice': 90, 'bob': 85};

    // This check succeeds.
    check(scores).length.equals(2);

    // This check fails.
    check(scores).length.isGreaterThan(5);
    // Expected: a Map<String, int> that has length: a value > <5>
    // Actual: a Map<String, int> that has length: <2>
    // Which: is not greater than <5>
  });
}
