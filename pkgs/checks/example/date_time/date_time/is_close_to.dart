import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isCloseTo', () {
    final time = DateTime.utc(2026, 1, 1, 12);
    const delta = Duration(seconds: 5);

    // This check succeeds.
    check(time).isCloseTo(DateTime.utc(2026, 1, 1, 12, 0, 1), delta);

    // This check succeeds. The delta is inclusive.
    check(time).isCloseTo(DateTime.utc(2026, 1, 1, 12, 0, 5), delta);

    // This check fails.
    check(time).isCloseTo(DateTime.utc(2026, 1, 1, 12, 0, 6), delta);
    // Expected: a DateTime that:
    //   is within <0:00:05.000000> of <2026-01-01 12:00:06.000Z>
    // Actual: <2026-01-01 12:00:00.000Z>
    // Which: differs by <0:00:06.000000>
  });
}
