import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isException', () {
    // This check succeeds.
    expect(const FormatException('bad input'), isException);

    // This check fails.
    expect(StateError('nope'), isException);
    // Expected: <Instance of 'Exception'>
    //   Actual: StateError:<Bad state: nope>
    //    Which: is not an instance of 'Exception'
  });
}
