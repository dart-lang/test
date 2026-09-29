import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsArgumentError', () {
    // This check succeeds.
    expect(() => throw ArgumentError('bad'), throwsArgumentError);

    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsArgumentError);
    // Expected: throws <Instance of 'ArgumentError'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
