import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throwsUnimplementedError', () {
    // This check succeeds.
    expect(() => throw UnimplementedError('todo'), throwsUnimplementedError);

    // This check fails, the function returned instead of throwing.
    expect(() => 42, throwsUnimplementedError);
    // Expected: throws <Instance of 'UnimplementedError'>
    //   Actual: <Closure: () => int>
    //    Which: returned <42>
  });
}
