import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isFalse', () {
    // This check succeeds.
    expect(false, isFalse);

    // This check fails.
    expect(true, isFalse);
    // Expected: false
    //   Actual: <true>
  });
}
