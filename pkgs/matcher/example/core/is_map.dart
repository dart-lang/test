import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isMap', () {
    // This check succeeds.
    expect({'a': 1}, isMap);

    // This check fails.
    expect([1, 2, 3], isMap);
    // Expected: <Instance of 'Map'>
    //   Actual: [1, 2, 3]
    //    Which: is not an instance of 'Map'
  });
}
