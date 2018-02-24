// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:test/src/runner/configuration.dart';

void main() {
  test('should merge with a base configuration', () async {
    await d.dir('repo', [
      d.file('dart_test_base.yaml', r'''
        filename: "test_*.dart"
      '''),
      d.dir('pkg', [
        d.file('dart_test.yaml', r'''
          include: ../dart_test_base.yaml
          concurrency: 3
        '''),
      ]),
    ]).create();
    var path = p.join(d.sandbox, 'repo', 'pkg', 'dart_test.yaml');
    var config = new Configuration.load(path);
    expect(config.filename.pattern, 'test_*.dart');
    expect(config.concurrency, 3);
  });
}
