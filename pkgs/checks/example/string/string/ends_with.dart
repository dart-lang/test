import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('endsWith', () {
    // This check succeeds.
    check('lib/src/extensions/string.dart').endsWith('.dart');

    // This check fails.
    check('lib/src/extensions/string.dart').endsWith('.js');
    // Expected: a string ending with '.js'
    // Actual: 'lib/src/extensions/string.dart'
    // Which: does not end with '.js'
  });
}
