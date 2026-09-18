import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('pairwiseCompare', () {
    // This check succeeds.
    expect(
      [1, 2, 3],
      pairwiseCompare<int, int>([2, 4, 6], (e, a) => e == a * 2, 'is half of'),
    );

    // This check fails.
    expect(
      [1, 2, 4],
      pairwiseCompare<int, int>([2, 4, 6], (e, a) => e == a * 2, 'is half of'),
    );
    // Expected: pairwise is half of [2, 4, 6]
    //   Actual: [1, 2, 4]
    //    Which: has <4> which is not is half of <6> at index 2
  });
}
