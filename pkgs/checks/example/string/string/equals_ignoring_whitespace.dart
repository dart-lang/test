import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('equalsIgnoringWhitespace', () {
    // This check succeeds.
    check('''  hello\t
      world  ''').equalsIgnoringWhitespace('hello world');

    // This check fails.
    check('hello   wide world').equalsIgnoringWhitespace('hello world');
    // Expected: a String that:
    //   equals ignoring whitespace 'hello world'
    // Actual: 'hello   wide world'
    // Which: with whitespace collapsed to 'hello wide world' it:
    //   differs at offset 7:
    //     hello world
    //     hello wide world
    //            ^
  });
}
