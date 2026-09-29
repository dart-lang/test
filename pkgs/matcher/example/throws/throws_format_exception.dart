import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsFormatException', () {
    // This check succeeds.
    expect(
      () => Error.throwWithStackTrace(
        const FormatException('bad input'),
        StackTrace.empty,
      ),
      throwsFormatException,
    );

    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsFormatException);
    // Expected: throws <Instance of 'FormatException'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
