import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsException', () {
    // This check succeeds.
    expect(
      () => Error.throwWithStackTrace(
        const FormatException('bad input'),
        StackTrace.empty,
      ),
      throwsException,
    );

    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsException);
    // Expected: throws <Instance of 'Exception'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
