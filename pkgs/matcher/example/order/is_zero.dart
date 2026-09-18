import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isZero', () {
    // This check succeeds.
    expect(0, isZero);

    // This check fails.
    expect(1, isZero);
    // Expected: a value equal to <0>
    //   Actual: <1>
    //    Which: is not a value equal to <0>
  });
}
