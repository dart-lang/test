// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

void main() {
  test('pub get gets dependencies', () async {
    // TestProcess.start() works just like Process.start() from dart:io.
    var process = await TestProcess.start('dart', ['pub', 'get']);

    // StreamQueue.next returns the next line emitted on standard out.
    var firstLine = await process.stdout.next;
    expect(firstLine, equals('Resolving dependencies...'));

    // Each call to StreamQueue.next moves one line further.
    String next;
    do {
      next = await process.stdout.next;
    } while (next != 'Got dependencies!');

    // Assert that the process exits with code 0.
    await process.shouldExit(0);
  });
}
