import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('expectLater', () async {
    // `expectLater` returns a future that completes when the matcher is done.
    await expectLater(Future.value(42), completion(42));

    // This check fails.
    await expectLater(Future.value(42), completion(7));
    // Expected: completes to a value that <7>
    //   Actual: <Instance of 'Future<int>'>
    //    Which: emitted <42>
  });
}
