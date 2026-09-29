import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('every', () {
    // This check succeeds.
    check([2, 4, 6]).every(.it()..isLessThan(10));

    // This check fails.
    check([2, 4, 16]).every(.it()..isLessThan(10));
    // Expected: a List<int> that:
    //   only has values that:
    //     is less than <10>
    // Actual: [2, 4, 16]
    // Which: has an element at index 2 that:
    //   Actual: <16>
    //   Which: is not less than <10>
  });
}
