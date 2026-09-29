import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isEmpty', () {
    // This check succeeds.
    expect('', isEmpty);

    // This check fails.
    expect('hello', isEmpty);
    // Expected: empty
    //   Actual: 'hello'
  });
}
