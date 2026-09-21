import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('same', () {
    final list = [1, 2, 3];

    // This check succeeds, it is the same instance.
    expect(list, same(list));

    // This check fails. The lists are equal but not identical.
    expect([1, 2, 3], same(list));
    // Expected: same instance as [1, 2, 3]
    //   Actual: [1, 2, 3]
  });
}
