import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsKey', () {
    final scores = {'alice': 90, 'bob': 85};

    // This check succeeds.
    check(scores).containsKey('alice');

    // This check fails.
    check(scores).containsKey('carol');
    // Expected: a map with key 'carol'
    // Actual: {'alice': 90, 'bob': 85}
    // Which: does not contain key 'carol'
  });
}
