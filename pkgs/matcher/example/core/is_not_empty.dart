import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotEmpty', () {
    // This check succeeds.
    expect([1, 2, 3], isNotEmpty);

    // This check fails.
    expect(<int>[], isNotEmpty);
    // Expected: non-empty
    //   Actual: []
  });
}
