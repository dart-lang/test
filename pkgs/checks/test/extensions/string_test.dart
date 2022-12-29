// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('StringChecks', () {
    test('contains', () {
      checkThat('bob').contains('bo');
      checkThat(
        softCheck<String>('bob', (p0) => p0.contains('kayleb')),
      ).isARejection(actual: "'bob'", which: ["Does not contain 'kayleb'"]);
    });
    test('length', () {
      checkThat('bob').length.equals(3);
    });
    test('isEmpty', () {
      checkThat('').isEmpty();
      checkThat(
        softCheck<String>('bob', (p0) => p0.isEmpty()),
      ).isARejection(actual: "'bob'", which: ['is not empty']);
    });
    test('isNotEmpty', () {
      checkThat('bob').isNotEmpty();
      checkThat(
        softCheck<String>('', (p0) => p0.isNotEmpty()),
      ).isARejection(actual: "''", which: ['is empty']);
    });
    test('startsWith', () {
      checkThat('bob').startsWith('bo');
      checkThat(
        softCheck<String>('bob', (p0) => p0.startsWith('kayleb')),
      ).isARejection(actual: "'bob'", which: ["does not start with 'kayleb'"]);
    });
    test('endsWith', () {
      checkThat('bob').endsWith('ob');
      checkThat(softCheck<String>('bob', (p0) => p0.endsWith('kayleb')))
          .isARejection(actual: "'bob'", which: ["does not end with 'kayleb'"]);
    });

    group('equals', () {
      test('succeeeds for happy case', () {
        checkThat('foo').equals('foo');
      });
      test('succeeeds for equal empty strings', () {
        checkThat('').equals('');
      });
      test('reports extra characters for long string', () {
        checkThat(softCheck<String>('foobar', (c) => c.equals('foo')))
            .isARejection(which: [
          'is too long with unexpected trailing characters:',
          'bar'
        ]);
      });
      test('reports extra characters for long string against empty', () {
        checkThat(softCheck<String>('foo', (c) => c.equals('')))
            .isARejection(which: ['is not the empty string']);
      });
      test('reports truncated extra characters for very long string', () {
        checkThat(softCheck<String>(
                'foobar baz more stuff', (c) => c.equals('foo')))
            .isARejection(which: [
          'is too long with unexpected trailing characters:',
          'bar baz mo ...'
        ]);
      });
      test('reports missing characters for short string', () {
        checkThat(softCheck<String>('foo', (c) => c.equals('foobar')))
            .isARejection(which: [
          'is too short with missing trailing characters:',
          'bar'
        ]);
      });
      test('reports missing characters for empty string', () {
        checkThat(softCheck<String>('', (c) => c.equals('foo bar baz')))
            .isARejection(actual: 'an empty string', which: [
          'is missing all expected characters:',
          'foo bar ba ...'
        ]);
      });
      test('reports truncated missing characters for very short string', () {
        checkThat(softCheck<String>(
                'foo', (c) => c.equals('foobar baz more stuff')))
            .isARejection(which: [
          'is too short with missing trailing characters:',
          'bar baz mo ...'
        ]);
      });
      test('reports index of different character', () {
        checkThat(softCheck<String>('hit', (c) => c.equals('hat')))
            .isARejection(which: [
          'differs at offset 1:',
          'hat',
          'hit',
          ' ^',
        ]);
      });
      test('reports truncated index of different character in large string',
          () {
        checkThat(softCheck<String>('blah blah blah hit blah blah blah',
                (c) => c.equals('blah blah blah hat blah blah blah')))
            .isARejection(which: [
          'differs at offset 16:',
          '... lah blah hat blah bl ...',
          '... lah blah hit blah bl ...',
          '              ^',
        ]);
      });
    });

    group('equalsIgnoringCase', () {
      test('succeeeds for happy case', () {
        checkThat('FOO').equalsIgnoringCase('foo');
        checkThat('foo').equalsIgnoringCase('FOO');
      });
      test('reports original extra characters for long string', () {
        checkThat(
                softCheck<String>('FOOBAR', (c) => c.equalsIgnoringCase('foo')))
            .isARejection(which: [
          'is too long with unexpected trailing characters:',
          'BAR'
        ]);
      });
      test('reports original missing characters for short string', () {
        checkThat(
                softCheck<String>('FOO', (c) => c.equalsIgnoringCase('fooBAR')))
            .isARejection(which: [
          'is too short with missing trailing characters:',
          'BAR'
        ]);
      });
      test('reports index of different character with original characters', () {
        checkThat(softCheck<String>('HiT', (c) => c.equalsIgnoringCase('hAt')))
            .isARejection(which: [
          'differs at offset 1:',
          'hAt',
          'HiT',
          ' ^',
        ]);
      });
    });
  });
}
