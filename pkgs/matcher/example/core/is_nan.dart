import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNaN', () {
    // This check succeeds.
    expect(double.nan, isNaN);

    // This check fails.
    expect(1.0, isNaN);
    // Expected: NaN
    //   Actual: <1.0>
  });
}
