import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('prints', () {
    // This check succeeds.
    expect(() => print('hello'), prints('hello\n'));

    // This check fails.
    expect(() => print('hello'), prints('world\n'));
    // Expected: prints 'world\n'
    //             ''
    //   Actual: <Closure: () => void>
    //    Which: printed 'hello\n'
    //                     ''
    //             which is different.
    //                   Expected: world\n
    //                     Actual: hello\n
    //                             ^
    //                    Differ at offset 0
  });
}
