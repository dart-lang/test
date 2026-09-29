import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsA', () {
    // A function that throws when it is called. It must take no arguments, so
    // wrap anything that does in a zero argument closure.
    expect(() => throw StateError('nope'), throwsA(isStateError));
  });

  test('throwsA on a future', () async {
    // A future that completes with an error. This is an asynchronous
    // expectation, so the result has to be awaited.
    await expectLater(
      Future<void>.error(StateError('nope')),
      throwsA(isStateError),
    );
  });

  test('throwsA on a function returning a future', () async {
    Future<void> failLater() async => throw StateError('nope');
    await expectLater(failLater, throwsA(isStateError));
  });

  test('throwsA when the function returns', () {
    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsA(isStateError));
    // Expected: throws <Instance of 'StateError'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
