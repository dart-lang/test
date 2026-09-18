import 'package:async/async.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('mayEmitMultiple', () async {
    final queue = StreamQueue(
      Stream.fromIterable(['warning', 'warning', 'done']),
    );

    // This check succeeds and consumes both matching events.
    await check(queue).mayEmitMultiple(.it()..equals('warning'));

    // This check also succeeds - the expectation never fails - but since the
    // next event does not match, no event is consumed.
    await check(queue).mayEmitMultiple(.it()..equals('warning'));

    // This check fails, showing that both warnings were consumed.
    await check(queue).emits(.it()..equals('warning'));
    // Expected: a StreamQueue<String> that emits 'warning'
    // Actual: a StreamQueue<String> that emits 'done'
    // Which: differs at offset 0:
    //   warning
    //   done
    //   ^
  });
}
