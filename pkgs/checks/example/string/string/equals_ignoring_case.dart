import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('equalsIgnoringCase', () {
    // This check succeeds.
    check('Hello World').equalsIgnoringCase('hello world');

    // This check fails.
    check('Hello World').equalsIgnoringCase('hello there');
    // Expected: a string equal to 'hello there' ignoring case
    // Actual: 'Hello World'
    // Which: differs at offset 6:
    //   hello there
    //   Hello World
    //         ^
  });
}
