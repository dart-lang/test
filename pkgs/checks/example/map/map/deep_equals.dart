import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('deepEquals', () {
    // This check succeeds.
    check({
      'alice': [90, 95],
      'bob': [85],
    }).deepEquals({
      'alice': [90, 95],
      'bob': [85],
    });

    // This check fails.
    check({
      'alice': [90, 95],
      'bob': [85],
    }).deepEquals({
      'alice': [90, 95],
      'bob': [80],
    });
    // Expected: {'alice': [90, 95], 'bob': [80]}
    // Actual: {'alice': [90, 95], 'bob': [85]}
    // Which: at ['bob'][<0>] is <85>
    // which does not equal <80>
  });
}
