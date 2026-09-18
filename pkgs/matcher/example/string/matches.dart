import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('matches', () {
    // This check succeeds.
    expect('hello world', matches(r'^h.*d$'));

    // This check fails.
    expect('hello world', matches(r'^w.*d$'));
    // Expected: match '^w.*d$'
    //   Actual: 'hello world'
  });
}
