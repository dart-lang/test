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
    expect(config.knownTags, unorderedEquals(['hello', 'world']));
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

  test('should handle a missing include gracefully', () async {
    await d.dir('repo', [
      d.dir('pkg', [
        d.file('dart_test.yaml', r'''
          include: other_test.yaml # Oops!
        '''),
      ]),
    ]).create();
    var path = p.join(d.sandbox, 'repo', 'pkg', 'dart_test.yaml');
    expect(() => new Configuration.load(path), throwsFormatException);
  });

  test('should not allow an include field in a test config context', () async {
    await d.dir('repo', [
      d.dir('pkg', [
        d.file('dart_test.yaml', r'''
          tags:
            foo:
              include: ../dart_test.yaml
        '''),
      ]),
    ]).create();
    var path = p.join(d.sandbox, 'repo', 'pkg', 'dart_test.yaml');
    expect(
        () => new Configuration.load(path),
        throwsA(allOf(isFormatException,
            predicate((e) => '$e'.contains('include isn\'t supported here')))));
  });

  test('should allow an include field in a runner config context', () async {
    await d.dir('repo', [
      d.dir('pkg', [
        d.file('dart_test.yaml', r'''
          presets:
            bar:
              include: other_dart_test.yaml
              pause_after_load: true
        '''),
        d.file('other_dart_test.yaml', r'''
          reporter: expanded
        '''),
      ]),
    ]).create();
    var path = p.join(d.sandbox, 'repo', 'pkg', 'dart_test.yaml');
    var config = new Configuration.load(path);
    var presetBar = config.presets['bar'];
    expect(presetBar.pauseAfterLoad, isTrue);
    expect(presetBar.reporter, 'expanded');
  });

  test('local configuration should take precedence after merging', () async {
    await d.dir('repo', [
      d.dir('pkg', [
        d.file('dart_test.yaml', r'''
          include: other_dart_test.yaml
          concurrency: 5
        '''),
        d.file('other_dart_test.yaml', r'''
          concurrency: 10
        '''),
      ]),
    ]).create();
    var path = p.join(d.sandbox, 'repo', 'pkg', 'dart_test.yaml');
    var config = new Configuration.load(path);
    expect(config.concurrency, 5);
  });
}
