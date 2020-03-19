// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// @dart=2.7

@TestOn('vm')
import 'package:boolean_selector/boolean_selector.dart';
import 'package:test/test.dart';

import 'package:test_api/src/backend/platform_selector.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_core/src/runner/runtime_selection.dart';
import 'package:test_core/src/runner/suite.dart';

void main() {
  group('merge', () {
    group('for most fields', () {
      test('if neither is defined, preserves the default', () {
        var merged = SuiteConfiguration().merge(SuiteConfiguration());
        expect(merged.jsTrace, isFalse);
        expect(merged.runSkipped, isFalse);
        expect(merged.precompiledPath, isNull);
        expect(merged.runtimes, equals([Runtime.vm.identifier]));
        expect(merged.testRandomizeOrderingSeed, null);
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = SuiteConfiguration(
                jsTrace: true,
                runSkipped: true,
                precompiledPath: '/tmp/js',
                runtimes: [RuntimeSelection(Runtime.chrome.identifier)])
            .merge(SuiteConfiguration());

        expect(merged.jsTrace, isTrue);
        expect(merged.runSkipped, isTrue);
        expect(merged.precompiledPath, equals('/tmp/js'));
        expect(merged.runtimes, equals([Runtime.chrome.identifier]));
      });

      test("if only the configuration's is defined, uses it", () {
        var merged = SuiteConfiguration().merge(SuiteConfiguration(
            jsTrace: true,
            runSkipped: true,
            precompiledPath: '/tmp/js',
            testRandomizeOrderingSeed: 1234,
            runtimes: [RuntimeSelection(Runtime.chrome.identifier)]));

        expect(merged.jsTrace, isTrue);
        expect(merged.runSkipped, isTrue);
        expect(merged.precompiledPath, equals('/tmp/js'));
        expect(merged.testRandomizeOrderingSeed, 1234);
        expect(merged.runtimes, equals([Runtime.chrome.identifier]));
      });

      test(
          "if the two configurations conflict, uses the configuration's "
          'values', () {
        var older = SuiteConfiguration(
            jsTrace: false,
            runSkipped: true,
            precompiledPath: '/tmp/js',
            runtimes: [RuntimeSelection(Runtime.chrome.identifier)]);
        var newer = SuiteConfiguration(
            jsTrace: true,
            runSkipped: false,
            precompiledPath: '../js',
            runtimes: [RuntimeSelection(Runtime.firefox.identifier)]);
        var merged = older.merge(newer);

        expect(merged.jsTrace, isTrue);
        expect(merged.runSkipped, isFalse);
        expect(merged.precompiledPath, equals('../js'));
        expect(merged.runtimes, equals([Runtime.firefox.identifier]));
      });
    });

    group('for include and excludeTags', () {
      test('if neither is defined, preserves the default', () {
        var merged = SuiteConfiguration().merge(SuiteConfiguration());
        expect(merged.includeTags, equals(BooleanSelector.all));
        expect(merged.excludeTags, equals(BooleanSelector.none));
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = SuiteConfiguration(
                includeTags: BooleanSelector.parse('foo || bar'),
                excludeTags: BooleanSelector.parse('baz || bang'))
            .merge(SuiteConfiguration());

        expect(merged.includeTags, equals(BooleanSelector.parse('foo || bar')));
        expect(
            merged.excludeTags, equals(BooleanSelector.parse('baz || bang')));
      });

      test("if only the configuration's is defined, uses it", () {
        var merged = SuiteConfiguration().merge(SuiteConfiguration(
            includeTags: BooleanSelector.parse('foo || bar'),
            excludeTags: BooleanSelector.parse('baz || bang')));

        expect(merged.includeTags, equals(BooleanSelector.parse('foo || bar')));
        expect(
            merged.excludeTags, equals(BooleanSelector.parse('baz || bang')));
      });

      test('if both are defined, unions or intersects them', () {
        var older = SuiteConfiguration(
            includeTags: BooleanSelector.parse('foo || bar'),
            excludeTags: BooleanSelector.parse('baz || bang'));
        var newer = SuiteConfiguration(
            includeTags: BooleanSelector.parse('blip'),
            excludeTags: BooleanSelector.parse('qux'));
        var merged = older.merge(newer);

        expect(merged.includeTags,
            equals(BooleanSelector.parse('(foo || bar) && blip')));
        expect(merged.excludeTags,
            equals(BooleanSelector.parse('(baz || bang) || qux')));
      });
    });

    group('for sets', () {
      test('if neither is defined, preserves the default', () {
        var merged = SuiteConfiguration().merge(SuiteConfiguration());
        expect(merged.patterns, isEmpty);
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = SuiteConfiguration(patterns: ['beep', 'boop'])
            .merge(SuiteConfiguration());

        expect(merged.patterns, equals(['beep', 'boop']));
      });

      test("if only the configuration's is defined, uses it", () {
        var merged = SuiteConfiguration()
            .merge(SuiteConfiguration(patterns: ['beep', 'boop']));

        expect(merged.patterns, equals(['beep', 'boop']));
      });

      test('if both are defined, unions them', () {
        var older = SuiteConfiguration(patterns: ['beep', 'boop']);
        var newer = SuiteConfiguration(patterns: ['bonk']);
        var merged = older.merge(newer);

        expect(merged.patterns, unorderedEquals(['beep', 'boop', 'bonk']));
      });
    });

    group('for dart2jsArgs', () {
      test('if neither is defined, preserves the default', () {
        var merged = SuiteConfiguration().merge(SuiteConfiguration());
        expect(merged.dart2jsArgs, isEmpty);
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = SuiteConfiguration(dart2jsArgs: ['--foo', '--bar'])
            .merge(SuiteConfiguration());
        expect(merged.dart2jsArgs, equals(['--foo', '--bar']));
      });

      test("if only the configuration's is defined, uses it", () {
        var merged = SuiteConfiguration()
            .merge(SuiteConfiguration(dart2jsArgs: ['--foo', '--bar']));
        expect(merged.dart2jsArgs, equals(['--foo', '--bar']));
      });

      test('if both are defined, concatenates them', () {
        var older = SuiteConfiguration(dart2jsArgs: ['--foo', '--bar']);
        var newer = SuiteConfiguration(dart2jsArgs: ['--baz']);
        var merged = older.merge(newer);
        expect(merged.dart2jsArgs, equals(['--foo', '--bar', '--baz']));
      });
    });

    group('for config maps', () {
      test('merges each nested configuration', () {
        var merged = SuiteConfiguration(tags: {
          BooleanSelector.parse('foo'):
              SuiteConfiguration(precompiledPath: 'path/'),
          BooleanSelector.parse('bar'): SuiteConfiguration(jsTrace: true)
        }, onPlatform: {
          PlatformSelector.parse('vm'):
              SuiteConfiguration(precompiledPath: 'path/'),
          PlatformSelector.parse('chrome'): SuiteConfiguration(jsTrace: true)
        }).merge(SuiteConfiguration(tags: {
          BooleanSelector.parse('bar'): SuiteConfiguration(jsTrace: false),
          BooleanSelector.parse('baz'): SuiteConfiguration(runSkipped: true)
        }, onPlatform: {
          PlatformSelector.parse('chrome'): SuiteConfiguration(jsTrace: false),
          PlatformSelector.parse('firefox'):
              SuiteConfiguration(runSkipped: true)
        }));

        expect(merged.tags[BooleanSelector.parse('foo')].precompiledPath,
            equals('path/'));
        expect(merged.tags[BooleanSelector.parse('bar')].jsTrace, isFalse);
        expect(merged.tags[BooleanSelector.parse('baz')].runSkipped, isTrue);

        expect(merged.onPlatform[PlatformSelector.parse('vm')].precompiledPath,
            'path/');
        expect(merged.onPlatform[PlatformSelector.parse('chrome')].jsTrace,
            isFalse);
        expect(merged.onPlatform[PlatformSelector.parse('firefox')].runSkipped,
            isTrue);
      });
    });
  });
}
