import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('inOpenClosedRange', () {
    // This check succeeds.
    expect(10, inOpenClosedRange(1, 10));

    // This check fails.
    expect(1, inOpenClosedRange(1, 10));
    // Expected: be in range from 1 (exclusive) to 10 (inclusive)
    //   Actual: <1>
  });
}
