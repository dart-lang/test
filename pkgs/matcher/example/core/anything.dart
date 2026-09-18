import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('anything', () {
    // These checks succeed. Any value at all matches.
    expect(42, anything);
    expect(null, anything);

    // There is no failing case. `anything` matches every value, including
    // null, so on its own it can never fail.
    //
    // It is useful as a placeholder within a larger matcher, to check the
    // parts of a structure that matter while ignoring the rest.
    expect({'id': 7, 'name': 'Alice'}, containsPair('name', anything));
    expect([1, 2, 3], orderedEquals([1, anything, 3]));
  });
}
