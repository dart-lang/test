import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

/// Always throws, with an empty stack trace so that the failure recorded in
/// [main] does not include a machine specific stack trace.
int readPort() => Error.throwWithStackTrace(
  StateError('no port configured'),
  StackTrace.empty,
);

void main() {
  test('returnsNormally', () {
    // This check succeeds. The returned subject checks the returned value.
    check(() => int.parse('42')).returnsNormally().equals(42);

    // This check fails.
    check(readPort).returnsNormally();
    // Expected: a () => int that:
    //   returns a value
    // Actual: a function that throws
    // Which: threw <Bad state: no port configured> at:
  });
}
