import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isTrue', () {
    // This check succeeds.
    expect(true, isTrue);

    // This check fails.
    expect(false, isTrue);
    // Expected: true
    //   Actual: <false>
  });
}
