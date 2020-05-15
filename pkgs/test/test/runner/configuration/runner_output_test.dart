// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

@TestOn('vm')
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:path/path.dart' as p;

import '../../io.dart';

void main() {
  test('defaults to stdout', () async {
    await d.file('test.dart', '''
      import 'package:test_core/src/runner.dart';
      import 'package:test_core/src/runner/configuration.dart';

      void main() {
        var r = Runner(Configuration.empty);

        r.run();
      }
    ''').create();
    var test = await runDart(['test.dart']);
    await test.shouldExit();
    expect(test.stdout, emitsThrough(contains('Some tests failed.')));
  });

  test('use file as standard reporter', () async {
    await d.file('test.dart', '''
      import 'package:test_core/src/runner.dart';
      import 'package:test_core/src/runner/configuration.dart';
      import 'dart:io';

      void main() async {
        var out = File('works.txt').openWrite();
        var r = Runner.withCustomOutputStream(Configuration.empty, out);

        await r.run();
        await out.flush();
        await out.close();
      }
    ''').create();
    var f = d.file('works.txt');
    await f.create();
    var test = await runDart(['test.dart']);
    await test.shouldExit(0);

    expect(test.stdout, emitsInOrder([emitsDone]));

    var output = File(p.join(d.sandbox, 'works.txt')).readAsStringSync();
    expect(output, contains('Some tests failed.'));
  });
}
