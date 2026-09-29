import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsValueThat', () {
    final scores = {'alice': 90, 'bob': 85};

    // This check succeeds.
    check(scores).containsValueThat(.it()..isGreaterThan(85));

    // This check fails.
    check(scores).containsValueThat(.it()..isGreaterThan(95));
    // Expected: a Map<String, int> that:
    //   contains a value that:
    //     is greater than <95>
    // Actual: {'alice': 90, 'bob': 85}
    // Which: contains no matching value
  });
}
