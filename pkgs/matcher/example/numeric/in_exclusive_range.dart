import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('inExclusiveRange', () {
    // This check succeeds.
    expect(5, inExclusiveRange(1, 10));

    // This check fails.
    expect(10, inExclusiveRange(1, 10));
    // Expected: be in range from 1 (exclusive) to 10 (exclusive)
    //   Actual: <10>
  });
}
