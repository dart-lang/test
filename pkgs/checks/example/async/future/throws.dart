import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throws', () async {
    await check(Future<int>.error(StateError('nope'))).throws<StateError>(
      .it()..has((e) => e.message, 'message').equals('nope'),
    );
  });

  test('throws on a future that completes to a value', () async {
    await check(Future.value(42)).throws();
    // Expected: a Future<int> that:
    //   completes to an error
    // Actual: completed to <42>
    // Which: did not throw
  });

  test(
    'throws on a future that completes to an error of another type',
    () async {
      await check(
        Future<int>.error(StateError('nope')),
      ).throws<ArgumentError>();
      // Expected: a Future<int> that:
      //   completes to an error of type ArgumentError
      // Actual: completed to error <Bad state: nope>
      // Which: threw an exception that is not a ArgumentError at:
    },
  );
}
