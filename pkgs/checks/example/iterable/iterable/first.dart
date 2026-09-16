import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('first', () {
    check([3, 1, 4]).first.equals(3);
  });

  test('first when the element does not match', () {
    check([3, 1, 4]).first.isGreaterThan(5);
    // Expected: a List<int> that has first element: a value > <5>
    // Actual: a List<int> that has first element: <3>
    // Which: is not greater than <5>
  });

  test('first of an empty iterable', () {
    check(<int>[]).first.equals(3);
    // Expected: a List<int> that:
    //   has first element
    // Actual: []
    // Which: has no elements
  });
}
