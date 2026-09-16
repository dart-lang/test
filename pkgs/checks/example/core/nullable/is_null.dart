import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNull', () {
    final config = {'host': 'example.com'};

    // This check succeeds.
    check(config['port']).isNull;

    // This check fails.
    check(config['host']).isNull;
    // Expected: null
    // Actual: 'example.com'
  });
}
