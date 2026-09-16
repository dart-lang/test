import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('emitsThrough', () async {
    // This check succeeds, the leading values are skipped and consumed.
    await check(
      Stream.fromIterable(['a', 'b', 'c']),
    ).withQueue.emitsThrough(.it()..equals('c'));

    // This check fails because no value matches.
    await check(
      Stream.fromIterable(['a', 'b', 'c']),
    ).withQueue.emitsThrough(.it()..equals('d'));
    // Expected: a Stream<String> that:
    //   emits any values then emits a value that:
    //     equals 'd'
    // Actual: a stream
    // Which: ended after emitting 3 elements with none matching
  });
}
