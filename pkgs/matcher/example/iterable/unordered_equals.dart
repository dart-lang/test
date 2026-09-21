import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('unorderedEquals', () {
    // This check succeeds.
    expect([3, 1, 2], unorderedEquals([1, 2, 3]));

    // This check fails.
    expect([1, 2], unorderedEquals([1, 2, 3]));
    // Expected: equals [1, 2, 3] unordered
    //   Actual: [1, 2]
    //    Which: has too few elements (2 < 3)
  });
}
