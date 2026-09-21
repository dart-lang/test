import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotNull', () {
    // This check succeeds.
    expect(42, isNotNull);

    // This check fails.
    expect(null, isNotNull);
    // Expected: not null
    //   Actual: <null>
  });
}
