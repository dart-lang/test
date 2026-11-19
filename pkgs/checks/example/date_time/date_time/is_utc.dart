import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isUtc', () {
    // This check succeeds.
    check(DateTime.utc(2026)).isUtc;

    // This check fails.
    check(DateTime(2026)).isUtc;
    // Expected: a UTC time
    // Actual: <2026-01-01 00:00:00.000>
    // Which: is local
  });
}
