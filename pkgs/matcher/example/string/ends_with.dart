import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('endsWith', () {
    // This check succeeds.
    expect('hello world', endsWith('world'));

    // This check fails.
    expect('hello world', endsWith('hello'));
    // Expected: a string ending with 'hello'
    //   Actual: 'hello world'
  });
}
