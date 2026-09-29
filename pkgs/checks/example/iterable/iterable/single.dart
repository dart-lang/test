import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('single', () {
    check([42]).single.equals(42);
  });

  test('single when the element does not match', () {
    check([42]).single.isGreaterThan(100);
    // Expected: a List<int> that has single element: a value > <100>
    // Actual: a List<int> that has single element: <42>
    // Which: is not greater than <100>
  });

  test('single of an iterable with more than one element', () {
    check([42, 43]).single.equals(42);
    // Expected: a List<int> that:
    //   has single element
    // Actual: [42, 43]
    // Which: has more than one element
  });
}
