import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('last', () {
    check([3, 1, 4]).last.equals(4);
  });

  test('last when the element does not match', () {
    check([3, 1, 4]).last.isGreaterThan(5);
    // Expected: a List<int> that has last element: a value > <5>
    // Actual: a List<int> that has last element: <4>
    // Which: is not greater than <5>
  });

  test('last of an empty iterable', () {
    check(<int>[]).last.equals(4);
    // Expected: a List<int> that:
    //   has last element
    // Actual: []
    // Which: has no elements
  });
}
