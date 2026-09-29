import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('closeTo', () {
    // This check succeeds.
    expect(3.14159, closeTo(3.14, 0.01));

    // This check fails.
    expect(3.14159, closeTo(3.0, 0.01));
    // Expected: a numeric value within <0.01> of <3.0>
    //   Actual: <3.14159>
    //    Which:  differs by <0.14158999999999988>
  });
}
