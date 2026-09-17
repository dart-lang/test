import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('which', () {
    // This check succeeds.
    check('banana').which(
      .it()
        ..isGreaterThan('apple')
        ..isLessThan('cherry'),
    );

    // This check fails.
    check('banana').which(
      .it()
        ..isGreaterThan('apple')
        ..isLessThan('avocado'),
    );
    // Expected: a String that:
    //   is greater than 'apple'
    //   is less than 'avocado'
    // Actual: 'banana'
    // Which: is not less than 'avocado'
  });
}
