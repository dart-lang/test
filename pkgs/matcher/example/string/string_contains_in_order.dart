import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('stringContainsInOrder', () {
    // The substrings need to appear in order, but not next to each other.
    expect(
      'abcdefghijklmnopqrstuvwxyz',
      stringContainsInOrder(['a', 'e', 'i', 'o', 'u']),
    );

    // This check fails, the substrings are present but out of order.
    expect(
      'abcdefghijklmnopqrstuvwxyz',
      stringContainsInOrder(['u', 'o', 'i', 'e', 'a']),
    );
    // Expected: a string containing 'u', 'o', 'i', 'e', 'a' in order
    //   Actual: 'abcdefghijklmnopqrstuvwxyz'
  });
}
