import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotA', () {
    final Object text = 'a string';

    // This check succeeds.
    check(text).isNotA<int>();

    // This check fails.
    check(text).isNotA<String>();
    // Expected: a Object that:
    //   is not a String
    // Actual: 'a string'
    // Which: is a String
  });
}
