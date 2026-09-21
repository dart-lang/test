import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsAll', () {
    // This check succeeds.
    expect([1, 2, 3, 4], containsAll([3, 1]));

    // This check fails.
    expect([1, 2, 3, 4], containsAll([1, 5]));
    // Expected: contains all of [1, 5]
    //   Actual: [1, 2, 3, 4]
    //    Which: has no match for <5> at index 1
  });
}
