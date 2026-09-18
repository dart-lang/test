import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isUnsupportedError', () {
    // This check succeeds.
    expect(UnsupportedError('nope'), isUnsupportedError);

    // This check fails.
    expect(StateError('nope'), isUnsupportedError);
    // Expected: <Instance of 'UnsupportedError'>
    //   Actual: StateError:<Bad state: nope>
    //    Which: is not an instance of 'UnsupportedError'
  });
}
