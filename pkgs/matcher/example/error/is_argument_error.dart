import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isArgumentError', () {
    // This check succeeds.
    expect(ArgumentError('bad'), isArgumentError);

    // This check fails.
    expect(StateError('nope'), isArgumentError);
    // Expected: <Instance of 'ArgumentError'>
    //   Actual: StateError:<Bad state: nope>
    //    Which: is not an instance of 'ArgumentError'
  });
}
