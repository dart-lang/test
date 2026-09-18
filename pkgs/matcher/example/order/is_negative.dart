import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNegative', () {
    // This check succeeds.
    expect(-1, isNegative);

    // This check fails.
    expect(0, isNegative);
    // Expected: a negative value
    //   Actual: <0>
    //    Which: is not a negative value
  });
}
