import 'package:async/async.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('mayEmit', () async {
    final queue = StreamQueue(Stream.fromIterable(['warning', 'done']));

    // This check succeeds and consumes the matching event.
    await check(queue).mayEmit(.it()..equals('warning'));

    // This check also succeeds - the expectation never fails - but since the
    // next event does not match, no event is consumed.
    await check(queue).mayEmit(.it()..equals('warning'));

    // This check fails, showing that only the first event was consumed.
    await check(queue).emits(.it()..equals('warning'));
    // Expected: a StreamQueue<String> that emits 'warning'
    // Actual: a StreamQueue<String> that emits 'done'
    // Which: differs at offset 0:
    //   warning
    //   done
    //   ^
  });
}
