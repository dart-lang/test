import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isStateError', () {
    // This check succeeds.
    expect(StateError('nope'), isStateError);

    // This check fails.
    expect(ArgumentError('bad'), isStateError);
    // Expected: <Instance of 'StateError'>
    //   Actual: ArgumentError:<Invalid argument(s): bad>
    //    Which: is not an instance of 'StateError'
  });
}
