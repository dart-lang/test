import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('hasLength', () {
    // This check succeeds.
    expect([1, 2, 3], hasLength(3));

    // This check fails.
    expect([1, 2, 3], hasLength(2));
    // Expected: an object with length of <2>
    //   Actual: [1, 2, 3]
    //    Which: has length of <3>
  });
}
