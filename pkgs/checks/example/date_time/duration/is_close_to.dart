import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isCloseTo', () {
    const duration = Duration(seconds: 10);
    const delta = Duration(seconds: 2);

    // This check succeeds.
    check(duration).isCloseTo(const Duration(seconds: 11), delta);

    // This check succeeds. The delta is inclusive.
    check(duration).isCloseTo(const Duration(seconds: 12), delta);

    // This check fails.
    check(duration).isCloseTo(const Duration(seconds: 13), delta);
    // Expected: a Duration that:
    //   is within <0:00:02.000000> of <0:00:13.000000>
    // Actual: <0:00:10.000000>
    // Which: differs by <0:00:03.000000>
  });
}
