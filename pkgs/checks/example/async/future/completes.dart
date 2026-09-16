import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('completes', () async {
    // This check succeeds.
    await check(Future.value(42)).completes(.it()..equals(42));

    // This check fails.
    await check(Future<int>.error(StateError('nope'))).completes();
    // Expected: a Future<int> that:
    //   completes to a value
    // Actual: a future that completes as an error
    // Which: threw <Bad state: nope> at:
  });
}
