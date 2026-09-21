import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isFormatException', () {
    // This check succeeds.
    expect(const FormatException('bad input'), isFormatException);

    // This check fails.
    expect(StateError('nope'), isFormatException);
    // Expected: <Instance of 'FormatException'>
    //   Actual: StateError:<Bad state: nope>
    //    Which: is not an instance of 'FormatException'
  });
}
