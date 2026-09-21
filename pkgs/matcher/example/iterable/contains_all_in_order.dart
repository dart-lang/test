import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsAllInOrder', () {
    // This check succeeds.
    expect([1, 2, 3, 4], containsAllInOrder([1, 3]));

    // This check fails.
    expect([1, 2, 3, 4], containsAllInOrder([3, 1]));
    // Expected: contains in order([3, 1])
    //   Actual: [1, 2, 3, 4]
    //    Which: did not find a value matching <1> following expected prior values
  });
}
