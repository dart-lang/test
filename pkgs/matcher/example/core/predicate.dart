import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('predicate', () {
    // This check succeeds.
    expect(4, predicate<int>((v) => v.isEven, 'is even'));

    // This check fails.
    expect(5, predicate<int>((v) => v.isEven, 'is even'));
    // Expected: is even
    //   Actual: <5>
  });
}
