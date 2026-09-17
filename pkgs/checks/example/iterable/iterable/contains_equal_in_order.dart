import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsEqualInOrder', () {
    // This check succeeds.
    check([1, 0, 2, 0, 3]).containsEqualInOrder([1, 2, 3]);

    // This check fails.
    check([1, 0, 2, 0, 3]).containsEqualInOrder([3, 2, 1]);
    // Expected: a List<int> that:
    //   contains, in order: [3, 2, 1]
    // Actual: [1, 0, 2, 0, 3]
    // Which: did not have an element equal to the expectation at index 1 <2>
  });
}
