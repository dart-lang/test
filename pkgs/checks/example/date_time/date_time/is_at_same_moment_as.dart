import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isAtSameMomentAs', () {
    final utc = DateTime.utc(2026, 1, 1, 12);

    // This check succeeds.
    check(utc).isAtSameMomentAs(DateTime.utc(2026, 1, 1, 12));

    // This check succeeds. The time zone is ignored.
    check(utc).isAtSameMomentAs(utc.toLocal());

    // This check fails.
    check(utc).isAtSameMomentAs(DateTime.utc(2026, 1, 1, 11));
    // Expected: a DateTime that:
    //   is at the same moment as <2026-01-01 11:00:00.000Z>
    // Actual: <2026-01-01 12:00:00.000Z>
    // Which: is <1:00:00.000000> after
  });
}
