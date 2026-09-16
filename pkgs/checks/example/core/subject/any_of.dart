import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('anyOf', () {
    // This check succeeds.
    check(200).anyOf([.it()..equals(200), .it()..equals(201)]);

    // This check fails.
    check(404).anyOf([.it()..equals(200), .it()..equals(201)]);
    // Expected: a int that:
    //   matches any condition in [<A value that:
    //     equals <200>>,
    //   <A value that:
    //     equals <201>>]
    // Actual: <404>
    // Which: did not match any condition
  });
}
