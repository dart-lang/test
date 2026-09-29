import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotNaN', () {
    // This check succeeds.
    expect(1.0, isNotNaN);

    // This check fails.
    expect(double.nan, isNotNaN);
    // Expected: not NaN
    //   Actual: <NaN>
  });
}
