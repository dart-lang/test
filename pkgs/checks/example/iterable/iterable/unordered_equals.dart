import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('unorderedEquals', () {
    // This check succeeds.
    check([
      'cherry',
      'apple',
      'banana',
    ]).unorderedEquals(['apple', 'banana', 'cherry']);

    // This check fails.
    check([
      'cherry',
      'apple',
      'durian',
    ]).unorderedEquals(['apple', 'banana', 'cherry']);
    // Expected: a List<String> that:
    //   unordered equals ['apple', 'banana', 'cherry']
    // Actual: ['cherry', 'apple', 'durian']
    // Which: has no element equal to the expected element at index 1: 'banana'
  });
}
