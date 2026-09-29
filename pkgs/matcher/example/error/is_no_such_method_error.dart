import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNoSuchMethodError', () {
    // This check succeeds.
    expect(
      NoSuchMethodError.withInvocation(
        Object(),
        Invocation.method(#missing, []),
      ),
      isNoSuchMethodError,
    );

    // This check fails.
    expect(StateError('nope'), isNoSuchMethodError);
    // Expected: <Instance of 'NoSuchMethodError'>
    //   Actual: StateError:<Bad state: nope>
    //    Which: is not an instance of 'NoSuchMethodError'
  });
}
