import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isA', () {
    final Object text = 'a string';
    final Object number = 42;

    // This check succeeds.
    check(text).isA<String>().equals('a string');

    // This check fails.
    check(number).isA<String>();
    // Expected: a Object that:
    //   is a String
    // Actual: <42>
    // Which: is a int
  });
}
