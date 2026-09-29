import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('prints (async)', () async {
    // This check succeeds.
    await check(
      () async => print('Hello, world!'),
    ).prints(.it()..equals('Hello, world!\n'));

    // This check fails.
    await check(
      () async => print('Hello, world!'),
    ).prints(.it()..equals('Goodbye!\n'));
    // Expected: a () => Future<void> that prints 'Goodbye!'
    // Actual: a () => Future<void> that prints 'Hello, world!'
    // Which: differs at offset 0:
    //   Goodbye!\n ...
    //   Hello, wor ...
    //   ^
  });
}
