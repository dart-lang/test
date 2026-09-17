import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNot', () {
    // This check succeeds.
    expect(42, isNot(equals(7)));

    // This check fails.
    expect(42, isNot(equals(42)));
    // Expected: not <42>
    //   Actual: <42>
  });
}
