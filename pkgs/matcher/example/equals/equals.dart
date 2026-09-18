import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('equals', () {
    // This check succeeds.
    expect('hello', equals('hello'));

    // This check fails.
    expect('hello', equals('world'));
    // Expected: 'world'
    //   Actual: 'hello'
    //    Which: is different.
    //           Expected: world
    //             Actual: hello
    //                     ^
    //            Differ at offset 0
  });
}
