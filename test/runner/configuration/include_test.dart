// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
import 'package:path/path.dart' as p;
import 'package:test/src/runner/configuration.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

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

  test('should merge fields with a base configuration', () async {
    await d.dir('repo', [
      d.file('dart_test_base.yaml', r'''
        tags:
          hello:
      '''),
      d.dir('pkg', [
        d.file('dart_test.yaml', r'''
          include: ../dart_test_base.yaml
          tags:
            world:
        '''),
      ]),
    ]).create();
    var path = p.join(d.sandbox, 'repo', 'pkg', 'dart_test.yaml');
    var config = new Configuration.load(path);
    expect(config.knownTags, ['hello', 'world']);
  });

  test('should allow an included file to include a file', () async {
    await d.dir('repo', [
      d.file('dart_test_base_base.yaml', r'''
        tags:
          tag:
      '''),
      d.file('dart_test_base.yaml', r'''
        include: dart_test_base_base.yaml
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
    expect(config.knownTags, ['tag']);
    expect(config.filename.pattern, 'test_*.dart');
    expect(config.concurrency, 3);
  });

  test('should handle a non-string include field value gracefully', () async {
    await d.dir('repo', [
      d.dir('pkg', [
        d.file('dart_test.yaml', r'''
          include: 3 # Oops!
        '''),
      ]),
    ]).create();
    var path = p.join(d.sandbox, 'repo', 'pkg', 'dart_test.yaml');
    expect(() => new Configuration.load(path), throwsFormatException);
  });

  test('should not allow an include field in a test config context', () async {
    expect(() => new Configuration.parse(['--include=dart_test.yaml']), throwsFormatException);
  });
}
