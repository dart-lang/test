import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isIn', () {
    // This check succeeds.
    expect(2, isIn([1, 2, 3]));

    // This check fails.
    expect(4, isIn([1, 2, 3]));
    // Expected: is in [1, 2, 3]
    //   Actual: <4>
  });
}
