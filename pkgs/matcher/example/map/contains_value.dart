import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsValue', () {
    // This check succeeds.
    expect({'alice': 90, 'bob': 85}, containsValue(90));

    // This check fails.
    expect({'alice': 90, 'bob': 85}, containsValue(70));
    // Expected: contains value <70>
    //   Actual: {'alice': 90, 'bob': 85}
  });
}
