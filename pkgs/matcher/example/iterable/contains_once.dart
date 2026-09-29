import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsOnce', () {
    // This check succeeds.
    expect([1, 2, 3], containsOnce(2));

    // This check fails.
    expect([1, 2, 2, 3], containsOnce(2));
    // Expected: contains once(<2>)
    //   Actual: [1, 2, 2, 3]
    //    Which: expected only one value matching <2> but found multiple: <2>, <2>
  });
}
