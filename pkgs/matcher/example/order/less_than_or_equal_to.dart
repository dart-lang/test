import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('lessThanOrEqualTo', () {
    // This check succeeds.
    expect(10, lessThanOrEqualTo(10));

    // This check fails.
    expect(11, lessThanOrEqualTo(10));
    // Expected: a value less than or equal to <10>
    //   Actual: <11>
    //    Which: is not a value less than or equal to <10>
  });
}
