import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isRangeError', () {
    // This check succeeds.
    expect(RangeError.value(42), isRangeError);

    // This check fails.
    expect(StateError('nope'), isRangeError);
    // Expected: <Instance of 'RangeError'>
    //   Actual: StateError:<Bad state: nope>
    //    Which: is not an instance of 'RangeError'
  });
}
