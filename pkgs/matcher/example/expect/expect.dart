import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('expect', () {
    // This check succeeds.
    expect(42, equals(42));

    // This check fails.
    expect(42, equals(7));
    // Expected: <7>
    //   Actual: <42>
  });
}
