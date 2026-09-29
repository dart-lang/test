import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('neverCalled', () async {
    // This check succeeds, the callback is never invoked.
    const Stream<int>.empty().listen(neverCalled);
    await Future<void>.delayed(Duration.zero);

    // This check fails, the callback is invoked with an event.
    Stream.fromIterable([1]).listen(neverCalled);
    await Future<void>.delayed(Duration.zero);
    // Callback should never have been called, but it was called with:
    // • <1>
  });
}
