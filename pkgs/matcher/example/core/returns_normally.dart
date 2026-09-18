import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('returnsNormally', () {
    // This check succeeds.
    expect(() => 42, returnsNormally);

    // This check fails. The error is thrown with an empty stack trace so that
    // the failure message does not include machine specific paths.
    expect(
      () => Error.throwWithStackTrace(StateError('nope'), StackTrace.empty),
      returnsNormally,
    );
    // Expected: return normally
    //   Actual: <Closure: () => Never>
    //    Which: threw StateError:<Bad state: nope>
  });
}
