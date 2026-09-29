import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsPair', () {
    // This check succeeds.
    expect({'alice': 90, 'bob': 85}, containsPair('alice', 90));

    // This check fails.
    expect({'alice': 90, 'bob': 85}, containsPair('alice', 70));
    // Expected: contains pair 'alice' => <70>
    //   Actual: {'alice': 90, 'bob': 85}
    //    Which:  contains key 'alice' but with value is <90>
  });
}
