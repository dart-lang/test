import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsMatchingInOrder', () {
    // This check succeeds.
    check([1, 10, 2, 10, 3]).containsMatchingInOrder([
      .it()..isLessThan(2),
      .it()..isLessThan(3),
      .it()..isLessThan(4),
    ]);

    // This check fails.
    check([
      1,
      10,
      2,
      10,
      3,
    ]).containsMatchingInOrder([.it()..isLessThan(2), .it()..isLessThan(0)]);
    // Expected: a List<int> that:
    //   contains, in order: [<A value that:
    //     is less than <2>>,
    //   <A value that:
    //     is less than <0>>]
    // Actual: [1, 10, 2, 10, 3]
    // Which: did not have an element matching the expectation at index 1 <A value that:
    //   is less than <0>>
  });
}
