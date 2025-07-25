// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:boolean_selector/boolean_selector.dart';
import 'package:test/test.dart';
import 'package:test_core/src/runner/configuration/reporters.dart';
import 'package:test_core/src/runner/suite.dart';
import 'package:test_core/src/util/io.dart';

import '../../utils.dart';

void main() {
  group('merge', () {
    group('for most fields', () {
      test('if neither is defined, preserves the default', () {
        var merged = configuration().merge(configuration());
        expect(merged.help, isFalse);
        expect(merged.version, isFalse);
        expect(merged.pauseAfterLoad, isFalse);
        expect(merged.debug, isFalse);
        expect(merged.color, equals(canUseSpecialChars));
        expect(merged.configurationPath, equals('dart_test.yaml'));
        expect(merged.reporter, equals(defaultReporter));
        expect(merged.fileReporters, isEmpty);
        expect(merged.shardIndex, isNull);
        expect(merged.totalShards, isNull);
        expect(merged.testRandomizeOrderingSeed, isNull);
        expect(merged.testSelections.keys.single, 'test');
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = configuration(
          help: true,
          version: true,
          pauseAfterLoad: true,
          debug: true,
          color: true,
          configurationPath: 'special_test.yaml',
          reporter: 'json',
          fileReporters: {'json': 'out.json'},
          shardIndex: 3,
          totalShards: 10,
          testRandomizeOrderingSeed: 123,
          testSelections: const {
            'bar': {TestSelection()},
          },
        ).merge(configuration());

        expect(merged.help, isTrue);
        expect(merged.version, isTrue);
        expect(merged.pauseAfterLoad, isTrue);
        expect(merged.debug, isTrue);
        expect(merged.color, isTrue);
        expect(merged.configurationPath, equals('special_test.yaml'));
        expect(merged.reporter, equals('json'));
        expect(merged.fileReporters, equals({'json': 'out.json'}));
        expect(merged.shardIndex, equals(3));
        expect(merged.totalShards, equals(10));
        expect(merged.testRandomizeOrderingSeed, 123);
        expect(merged.testSelections.keys.single, 'bar');
      });

      test("if only the new configuration's is defined, uses it", () {
        var merged = configuration().merge(
          configuration(
            help: true,
            version: true,
            pauseAfterLoad: true,
            debug: true,
            color: true,
            configurationPath: 'special_test.yaml',
            reporter: 'json',
            fileReporters: {'json': 'out.json'},
            shardIndex: 3,
            totalShards: 10,
            testRandomizeOrderingSeed: 123,
            testSelections: const {
              'bar': {TestSelection()},
            },
          ),
        );

        expect(merged.help, isTrue);
        expect(merged.version, isTrue);
        expect(merged.pauseAfterLoad, isTrue);
        expect(merged.debug, isTrue);
        expect(merged.color, isTrue);
        expect(merged.configurationPath, equals('special_test.yaml'));
        expect(merged.reporter, equals('json'));
        expect(merged.fileReporters, equals({'json': 'out.json'}));
        expect(merged.shardIndex, equals(3));
        expect(merged.totalShards, equals(10));
        expect(merged.testRandomizeOrderingSeed, 123);
        expect(merged.testSelections.keys.single, 'bar');
      });

      test("if the two configurations conflict, uses the new configuration's "
          'values', () {
        var older = configuration(
          help: true,
          version: false,
          pauseAfterLoad: true,
          debug: true,
          color: false,
          configurationPath: 'special_test.yaml',
          reporter: 'json',
          fileReporters: {'json': 'old.json'},
          shardIndex: 2,
          totalShards: 4,
          testRandomizeOrderingSeed: 0,
          testSelections: const {
            'bar': {TestSelection()},
          },
        );
        var newer = configuration(
          help: false,
          version: true,
          pauseAfterLoad: false,
          debug: false,
          color: true,
          configurationPath: 'test_special.yaml',
          reporter: 'compact',
          fileReporters: {'json': 'new.json'},
          shardIndex: 3,
          totalShards: 10,
          testRandomizeOrderingSeed: 123,
          testSelections: const {
            'blech': {TestSelection()},
          },
        );
        var merged = older.merge(newer);

        expect(merged.help, isFalse);
        expect(merged.version, isTrue);
        expect(merged.pauseAfterLoad, isFalse);
        expect(merged.debug, isFalse);
        expect(merged.color, isTrue);
        expect(merged.configurationPath, equals('test_special.yaml'));
        expect(merged.reporter, equals('compact'));
        expect(merged.fileReporters, equals({'json': 'new.json'}));
        expect(merged.shardIndex, equals(3));
        expect(merged.totalShards, equals(10));
        expect(merged.testRandomizeOrderingSeed, 123);
        expect(merged.testSelections.keys.single, 'blech');
      });
    });

    group('for chosenPresets', () {
      test('if neither is defined, preserves the default', () {
        var merged = configuration().merge(configuration());
        expect(merged.chosenPresets, isEmpty);
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = configuration(
          chosenPresets: ['baz', 'bang'],
        ).merge(configuration());
        expect(merged.chosenPresets, equals(['baz', 'bang']));
      });

      test("if only the new configuration's is defined, uses it", () {
        var merged = configuration().merge(
          configuration(chosenPresets: ['baz', 'bang']),
        );
        expect(merged.chosenPresets, equals(['baz', 'bang']));
      });

      test('if both are defined, unions them', () {
        var merged = configuration(
          chosenPresets: ['baz', 'bang'],
        ).merge(configuration(chosenPresets: ['qux']));
        expect(merged.chosenPresets, equals(['baz', 'bang', 'qux']));
      });
    });

    group('for presets', () {
      test('merges each nested configuration', () {
        var merged = configuration(
          presets: {
            'bang': configuration(pauseAfterLoad: true),
            'qux': configuration(color: true),
          },
        ).merge(
          configuration(
            presets: {
              'qux': configuration(color: false),
              'zap': configuration(help: true),
            },
          ),
        );

        expect(merged.presets['bang']!.pauseAfterLoad, isTrue);
        expect(merged.presets['qux']!.color, isFalse);
        expect(merged.presets['zap']!.help, isTrue);
      });

      test('automatically resolves a matching chosen preset', () {
        var config = configuration(
          presets: {'foo': configuration(color: true)},
          chosenPresets: ['foo'],
        );
        expect(config.presets, isEmpty);
        expect(config.chosenPresets, equals(['foo']));
        expect(config.knownPresets, equals(['foo']));
        expect(config.color, isTrue);
      });

      test('resolves a chosen presets in order', () {
        var config = configuration(
          presets: {
            'foo': configuration(color: true),
            'bar': configuration(color: false),
          },
          chosenPresets: ['foo', 'bar'],
        );
        expect(config.presets, isEmpty);
        expect(config.chosenPresets, equals(['foo', 'bar']));
        expect(config.knownPresets, unorderedEquals(['foo', 'bar']));
        expect(config.color, isFalse);

        config = configuration(
          presets: {
            'foo': configuration(color: true),
            'bar': configuration(color: false),
          },
          chosenPresets: ['bar', 'foo'],
        );
        expect(config.presets, isEmpty);
        expect(config.chosenPresets, equals(['bar', 'foo']));
        expect(config.knownPresets, unorderedEquals(['foo', 'bar']));
        expect(config.color, isTrue);
      });

      test('ignores inapplicable chosen presets', () {
        var config = configuration(presets: {}, chosenPresets: ['baz']);
        expect(config.presets, isEmpty);
        expect(config.chosenPresets, equals(['baz']));
        expect(config.knownPresets, equals(isEmpty));
      });

      test('resolves presets through merging', () {
        var config = configuration(
          presets: {'foo': configuration(color: true)},
        ).merge(configuration(chosenPresets: ['foo']));

        expect(config.presets, isEmpty);
        expect(config.chosenPresets, equals(['foo']));
        expect(config.knownPresets, equals(['foo']));
        expect(config.color, isTrue);
      });

      test('preserves known presets through merging', () {
        var config = configuration(
          presets: {'foo': configuration(color: true)},
          chosenPresets: ['foo'],
        ).merge(configuration());

        expect(config.presets, isEmpty);
        expect(config.chosenPresets, equals(['foo']));
        expect(config.knownPresets, equals(['foo']));
        expect(config.color, isTrue);
      });
    });

    group('for include and excludeTags', () {
      test('if neither is defined, preserves the default', () {
        var merged = configuration().merge(configuration());
        expect(merged.includeTags, equals(BooleanSelector.all));
        expect(merged.excludeTags, equals(BooleanSelector.none));
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = configuration(
          includeTags: BooleanSelector.parse('foo || bar'),
          excludeTags: BooleanSelector.parse('baz || bang'),
        ).merge(configuration());

        expect(merged.includeTags, equals(BooleanSelector.parse('foo || bar')));
        expect(
          merged.excludeTags,
          equals(BooleanSelector.parse('baz || bang')),
        );
      });

      test("if only the configuration's is defined, uses it", () {
        var merged = configuration().merge(
          configuration(
            includeTags: BooleanSelector.parse('foo || bar'),
            excludeTags: BooleanSelector.parse('baz || bang'),
          ),
        );

        expect(merged.includeTags, equals(BooleanSelector.parse('foo || bar')));
        expect(
          merged.excludeTags,
          equals(BooleanSelector.parse('baz || bang')),
        );
      });

      test('if both are defined, unions or intersects them', () {
        var older = configuration(
          includeTags: BooleanSelector.parse('foo || bar'),
          excludeTags: BooleanSelector.parse('baz || bang'),
        );
        var newer = configuration(
          includeTags: BooleanSelector.parse('blip'),
          excludeTags: BooleanSelector.parse('qux'),
        );
        var merged = older.merge(newer);

        expect(
          merged.includeTags,
          equals(BooleanSelector.parse('(foo || bar) && blip')),
        );
        expect(
          merged.excludeTags,
          equals(BooleanSelector.parse('(baz || bang) || qux')),
        );
      });
    });

    group('for globalPatterns', () {
      test('if neither is defined, preserves the default', () {
        var merged = configuration().merge(configuration());
        expect(merged.globalPatterns, isEmpty);
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = configuration(
          globalPatterns: ['beep', 'boop'],
        ).merge(configuration());

        expect(merged.globalPatterns, equals(['beep', 'boop']));
      });

      test("if only the new configuration's is defined, uses it", () {
        var merged = configuration().merge(
          configuration(globalPatterns: ['beep', 'boop']),
        );

        expect(merged.globalPatterns, equals(['beep', 'boop']));
      });

      test('if both are defined, unions them', () {
        var older = configuration(globalPatterns: ['beep', 'boop']);
        var newer = configuration(globalPatterns: ['bonk']);
        var merged = older.merge(newer);

        expect(
          merged.globalPatterns,
          unorderedEquals(['beep', 'boop', 'bonk']),
        );
      });
    });
  });
}
