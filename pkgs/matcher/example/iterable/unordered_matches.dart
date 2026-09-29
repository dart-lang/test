import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('unorderedMatches', () {
    // This check succeeds.
    expect([3, 1, 2], unorderedMatches([lessThan(2), 2, greaterThan(2)]));

    // This check fails.
    expect([3, 1, 2], unorderedMatches([lessThan(2), 2, greaterThan(5)]));
    // Expected: matches [a value less than <2>, <2>, a value greater than <5>] unordered
    //   Actual: [3, 1, 2]
    //    Which: has no match for a value greater than <5> at index 2
  });
}
