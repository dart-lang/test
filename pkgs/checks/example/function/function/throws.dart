import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('throws', () {
    // This check succeeds.
    check(() => int.parse('not a number')).throws<FormatException>();

    // This check succeeds. The returned subject checks the thrown error.
    check(() => int.parse('not a number')).throws<FormatException>(
      .it()..has('source', (e) => e.source).equals('not a number'),
    );

    // This check fails.
    check(() => int.parse('42')).throws<FormatException>();
    // Expected: a () => int that:
    //   throws an error of type FormatException
    // Actual: a function that returned <42>
    // Which: did not throw
  });
}
