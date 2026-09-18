import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('prints', () {
    // This check succeeds. The returned subject checks the printed output.
    check(() => print('Hello, world!')).prints().equals('Hello, world!\n');

    // This check fails.
    check(() => print('Hello, world!')).prints(.it()..equals('Goodbye!\n'));
    // Expected: a () => void that prints 'Goodbye!'
    // Actual: a () => void that prints 'Hello, world!'
    // Which: differs at offset 0:
    //   Goodbye!\n ...
    //   Hello, wor ...
    //   ^
  });
}
