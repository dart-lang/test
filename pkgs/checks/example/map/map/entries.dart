import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('entries', () {
    final scores = {'alice': 90, 'bob': 85};

    // This check succeeds.
    check(scores).entries.length.equals(2);

    // This check fails.
    check(scores).entries.isEmpty;
    // Expected: a Map<String, int> that has entries: an empty iterable
    // Actual: a Map<String, int> that has entries: (MapEntry(alice: 90), MapEntry(bob: 85))
    // Which: is not empty
  });
}
