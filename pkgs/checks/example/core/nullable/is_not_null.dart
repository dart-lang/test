import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isNotNull', () {
    final config = {'host': 'example.com'};

    // This check succeeds.
    check(config['host']).isNotNull().equals('example.com');

    // This check fails.
    check(config['port']).isNotNull();
    // Expected: a String? that:
    //   is not null
    // Actual: <null>
  });
}
