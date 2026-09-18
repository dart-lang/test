import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('equals', () {
    // This check succeeds.
    check('hello').equals('hello');

    // This check fails.
    check('hello').equals('world');
    // Expected: 'world'
    // Actual: 'hello'
    // Which: differs at offset 0:
    //   world
    //   hello
    //   ^
  });
}
