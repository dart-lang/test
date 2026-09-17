import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('completion', () async {
    // This check succeeds.
    await expectLater(Future.value(42), completion(42));

    // This check fails.
    await expectLater(Future.value(42), completion(7));
    // Expected: completes to a value that <7>
    //   Actual: <Instance of 'Future<int>'>
    //    Which: emitted <42>
  });
}
