import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('not', () {
    // This check succeeds.
    check('hello').not(.it()..equals('goodbye'));

    // This check fails.
    check('hello').not(.it()..equals('hello'));
    // Expected: a String that:
    //   is not a value that:
    //       equals 'hello'
    // Actual: 'hello'
    // Which: is a value that:
    //     equals 'hello'
  });
}
