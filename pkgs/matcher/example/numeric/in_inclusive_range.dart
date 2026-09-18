import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('inInclusiveRange', () {
    // This check succeeds.
    expect(10, inInclusiveRange(1, 10));

    // This check fails.
    expect(11, inInclusiveRange(1, 10));
    // Expected: be in range from 1 (inclusive) to 10 (inclusive)
    //   Actual: <11>
  });
}
