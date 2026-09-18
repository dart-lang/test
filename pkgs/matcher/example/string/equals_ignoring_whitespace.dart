import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('equalsIgnoringWhitespace', () {
    // Runs of whitespace are collapsed to a single space, and leading and
    // trailing whitespace is removed, before the two strings are compared.
    expect('hello   world', equalsIgnoringWhitespace('hello world'));
    expect('  hello world', equalsIgnoringWhitespace('hello world'));
    expect('hello world  ', equalsIgnoringWhitespace('hello world'));

    // Tabs and newlines are whitespace as well as spaces.
    expect('hello\tworld', equalsIgnoringWhitespace('hello world'));
    expect('''
      hello
      world
    ''', equalsIgnoringWhitespace('hello world'));
  });

  test('equalsIgnoringWhitespace when the text differs', () {
    expect('hello wide world', equalsIgnoringWhitespace('hello world'));
    // Expected: 'hello world' ignoring whitespace
    //   Actual: 'hello wide world'
    //    Which: is 'hello wide world' with whitespace compressed
  });

  test('equalsIgnoringWhitespace when whitespace is missing', () {
    // Whitespace is collapsed, never removed, so a missing space does not
    // match.
    expect('helloworld', equalsIgnoringWhitespace('hello world'));
    // Expected: 'hello world' ignoring whitespace
    //   Actual: 'helloworld'
    //    Which: is 'helloworld' with whitespace compressed
  });
}
