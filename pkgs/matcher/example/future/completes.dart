import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('completes', () async {
    // This check succeeds.
    await expectLater(Future.value(42), completes);

    // This check fails, the future completes to an error.
    await expectLater(Future<int>.error(StateError('nope')), completes);
    // Bad state: nope
  });
}
