import 'dart:async';

import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('doesNotComplete', () async {
    // This check succeeds, the future never completes.
    await expectLater(Completer<int>().future, doesNotComplete);

    // This check fails.
    await expectLater(Future.value(42), doesNotComplete);
    // Future was not expected to complete but completed with a value of 42
  });
}
