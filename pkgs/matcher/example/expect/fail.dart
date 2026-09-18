import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('fail', () {
    // `fail` always throws, so it is only reached on a path that should not
    // happen. Here the value is checked first.
    final value = 42;
    if (value != 42) fail('the answer changed');

    // This call fails unconditionally.
    fail('the answer changed');
    // the answer changed
  });
}
