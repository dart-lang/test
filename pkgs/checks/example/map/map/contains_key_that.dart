import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsKeyThat', () {
    final scores = {'alice': 90, 'bob': 85};

    // This check succeeds.
    check(scores).containsKeyThat(.it()..startsWith('a'));

    // This check fails.
    check(scores).containsKeyThat(.it()..startsWith('z'));
    // Expected: a Map<String, int> that:
    //   contains a key that:
    //     starts with 'z'
    // Actual: {'alice': 90, 'bob': 85}
    // Which: contains no matching key
  });
}
