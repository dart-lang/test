import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('keys', () {
    final scores = {'alice': 90, 'bob': 85};

    // This check succeeds.
    check(scores).keys.contains('alice');

    // This check fails.
    check(scores).keys.contains('carol');
    // Expected: a Map<String, int> that has keys: an iterable containing 'carol'
    // Actual: a Map<String, int> that has keys: ('alice', 'bob')
    // Which: does not contain 'carol'
  });
}
