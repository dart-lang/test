import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('orderedEquals', () {
    // This check succeeds.
    expect([1, 2, 3], orderedEquals([1, 2, 3]));

    // This check fails.
    expect([1, 3, 2], orderedEquals([1, 2, 3]));
    // Expected: equals [1, 2, 3] ordered
    //   Actual: [1, 3, 2]
    //    Which: at location [1] is <3> instead of <2>
  });
}
