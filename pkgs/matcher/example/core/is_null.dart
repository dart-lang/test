import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNull', () {
    // This check succeeds.
    expect(null, isNull);

    // This check fails.
    expect(42, isNull);
    // Expected: null
    //   Actual: <42>
  });
}
