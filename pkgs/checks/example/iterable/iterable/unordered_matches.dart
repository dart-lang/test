import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('unorderedMatches', () {
    // This check succeeds.
    check([5, 1, 3]).unorderedMatches([
      .it()..isGreaterThan(4),
      .it()..isLessThan(2),
      .it()..equals(3),
    ]);

    // This check fails.
    check([5, 1, 3]).unorderedMatches([
      .it()..isGreaterThan(4),
      .it()..isLessThan(2),
      .it()..equals(2),
    ]);
    // Expected: a List<int> that:
    //   unordered matches [<A value that:
    //     is greater than <4>>,
    //   <A value that:
    //     is less than <2>>,
    //   <A value that:
    //     equals <2>>]
    // Actual: [5, 1, 3]
    // Which: has no element matching the condition at index 2:
    //   equals <2>
  });
}
