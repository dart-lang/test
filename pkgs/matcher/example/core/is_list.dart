import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isList', () {
    // This check succeeds.
    expect([1, 2, 3], isList);

    // This check fails.
    expect({'a': 1}, isList);
    // Expected: <Instance of 'List'>
    //   Actual: {'a': 1}
    //    Which: is not an instance of 'List'
  });
}
