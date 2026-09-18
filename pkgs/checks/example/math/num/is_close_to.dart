import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('isCloseTo', () {
    // This check succeeds.
    check(10.25).isCloseTo(10.0, 0.5);

    // This check succeeds. The delta is inclusive.
    check(10.5).isCloseTo(10.0, 0.5);

    // This check fails.
    check(10.75).isCloseTo(10.0, 0.5);
    // Expected: a value within <0.5> of <10.0>
    // Actual: <10.75>
    // Which: differs by <0.75>
  });
}
