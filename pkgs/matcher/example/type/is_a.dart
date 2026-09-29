import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isA', () {
    // This check succeeds.
    expect('hello', isA<String>());

    // This check fails.
    expect(42, isA<String>());
    // Expected: <Instance of 'String'>
    //   Actual: <42>
    //    Which: is not an instance of 'String'
  });
}
