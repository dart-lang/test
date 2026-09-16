import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('equals', () {
    check('hello world').equals('hello world');
  });

  test('equals a string differing in the middle', () {
    check('hello world').equals('hello there');
    // Expected: 'hello there'
    // Actual: 'hello world'
    // Which: differs at offset 6:
    //   hello there
    //   hello world
    //         ^
  });

  test('equals a string with extra trailing characters', () {
    check('hello world!').equals('hello world');
    // Expected: 'hello world'
    // Actual: 'hello world!'
    // Which: is too long with unexpected trailing characters:
    // !
  });

  test('equals a string with missing trailing characters', () {
    check('hello').equals('hello world');
    // Expected: 'hello world'
    // Actual: 'hello'
    // Which: is too short with missing trailing characters:
    //  world
  });
}
