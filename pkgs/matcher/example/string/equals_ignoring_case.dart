import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('equalsIgnoringCase', () {
    // This check succeeds.
    expect('Hello', equalsIgnoringCase('hello'));

    // This check fails.
    expect('Hello', equalsIgnoringCase('world'));
    // Expected: 'world' ignoring case
    //   Actual: 'Hello'
  });
}
