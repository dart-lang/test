import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNonZero', () {
    // This check succeeds.
    expect(1, isNonZero);

    // This check fails.
    expect(0, isNonZero);
    // Expected: a value not equal to <0>
    //   Actual: <0>
    //    Which: is not a value not equal to <0>
  });
}
