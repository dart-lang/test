import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('contains', () {
    // This check succeeds.
    expect([1, 2, 3], contains(2));

    // This check fails.
    expect([1, 2, 3], contains(4));
    // Expected: contains <4>
    //   Actual: [1, 2, 3]
    //    Which: does not contain <4>
  });
}
