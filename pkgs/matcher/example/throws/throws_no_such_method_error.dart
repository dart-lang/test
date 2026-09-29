import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsNoSuchMethodError', () {
    // This check succeeds.
    expect(
      () => Error.throwWithStackTrace(
        NoSuchMethodError.withInvocation(
          Object(),
          Invocation.method(#missing, []),
        ),
        StackTrace.empty,
      ),
      throwsNoSuchMethodError,
    );

    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsNoSuchMethodError);
    // Expected: throws <Instance of 'NoSuchMethodError'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
