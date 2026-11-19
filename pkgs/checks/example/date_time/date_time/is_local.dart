import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isLocal', () {
    // This check succeeds.
    check(DateTime(2026)).isLocal;

    // This check fails.
    check(DateTime.utc(2026)).isLocal;
    // Expected: a local time
    // Actual: <2026-01-01 00:00:00.000Z>
    // Which: is in UTC
  });
}
