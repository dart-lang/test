import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('pairwiseMatches', () {
    // This check succeeds.
    check([2, 4, 6]).pairwiseMatches(
      [1, 3, 5],
      (e) => .it()..isGreaterThan(e),
      'is greater than',
    );

    // This check fails.
    check([2, 4, 6]).pairwiseMatches(
      [1, 3, 7],
      (e) => .it()..isGreaterThan(e),
      'is greater than',
    );
    // Expected: a List<int> that:
    //   pairwise is greater than [1, 3, 7]
    // Actual: [2, 4, 6]
    // Which: does not have an element at index 2 that:
    //   is greater than <7>
    //   Actual element at index 2: <6>
    //   Which: is not greater than <7>
  });
}
