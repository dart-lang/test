import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('containsInOrder', () {
    // This check succeeds.
    check('The quick brown fox').containsInOrder(['The', 'brown', 'fox']);

    // This check fails.
    check('The quick brown fox').containsInOrder(['fox', 'quick']);
    // Expected: a String that:
    //   contains, in order: ['fox', 'quick']
    // Actual: 'The quick brown fox'
    // Which: does not have a match for the substring 'quick'
    // following the other matches up to character 19
  });
}
