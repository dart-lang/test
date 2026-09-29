import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('startsWith', () {
    // This check succeeds.
    expect('hello world', startsWith('hello'));

    // This check fails.
    expect('hello world', startsWith('world'));
    // Expected: a string starting with 'world'
    //   Actual: 'hello world'
  });
}
