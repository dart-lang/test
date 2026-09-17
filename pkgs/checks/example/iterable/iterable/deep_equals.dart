import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('deepEquals', () {
    // This check succeeds.
    check([
      1,
      [2, 3],
    ]).deepEquals([
      1,
      [2, 3],
    ]);

    // This check fails.
    check([
      1,
      [2, 3],
    ]).deepEquals([
      1,
      [2, 4],
    ]);
    // Expected: [1, [2, 4]]
    // Actual: [1, [2, 3]]
    // Which: at [<1>][<1>] is <3>
    // which does not equal <4>
  });
}
