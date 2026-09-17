import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsUnsupportedError', () {
    // This check succeeds.
    expect(() => throw UnsupportedError('nope'), throwsUnsupportedError);

    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsUnsupportedError);
    // Expected: throws <Instance of 'UnsupportedError'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
