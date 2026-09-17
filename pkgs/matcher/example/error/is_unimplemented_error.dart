import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isUnimplementedError', () {
    // This check succeeds.
    expect(UnimplementedError('todo'), isUnimplementedError);

    // This check fails.
    expect(StateError('nope'), isUnimplementedError);
    // Expected: <Instance of 'UnimplementedError'>
    //   Actual: StateError:<Bad state: nope>
    //    Which: is not an instance of 'UnimplementedError'
  });
}
