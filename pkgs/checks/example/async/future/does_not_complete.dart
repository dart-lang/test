import 'dart:async';

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('doesNotComplete', () async {
    // This check succeeds.
    check(Completer<int>().future).doesNotComplete;

    // This check fails. The failure is reported asynchronously, after the
    // future completes.
    final completer = Completer<int>();
    check(completer.future).doesNotComplete;
    completer.complete(42);
    // Expected: a Future<int> that:
    //   does not complete
    // Actual: a future that completed to <42>
  });
}
