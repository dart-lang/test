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
        softCheck<String>('bob', it()..contains('kayleb')),
      ).isARejection(actual: ["'bob'"], which: ["Does not contain 'kayleb'"]);
    });
    test('length', () {
      checkThat('bob').length.equals(3);
    });
    test('isEmpty', () {
      checkThat('').isEmpty();
      checkThat(
        softCheck<String>('bob', it()..isEmpty()),
      ).isARejection(actual: ["'bob'"], which: ['is not empty']);
    });
    test('isNotEmpty', () {
      checkThat('bob').isNotEmpty();
      checkThat(
        softCheck<String>('', it()..isNotEmpty()),
      ).isARejection(actual: ["''"], which: ['is empty']);
    });
    test('startsWith', () {
      checkThat('bob').startsWith('bo');
      checkThat(
        softCheck<String>('bob', it()..startsWith('kayleb')),
      ).isARejection(
          actual: ["'bob'"], which: ["does not start with 'kayleb'"]);
    });
    test('endsWith', () {
      checkThat('bob').endsWith('ob');
      checkThat(softCheck<String>('bob', it()..endsWith('kayleb')))
          .isARejection(
              actual: ["'bob'"], which: ["does not end with 'kayleb'"]);
    });

    group('containsInOrder', () {
      test('happy case', () {
        checkThat('foo bar baz').containsInOrder(['foo', 'baz']);
      });
      test('reports when first substring is missing', () {
        checkThat(
                softCheck<String>('baz', it()..containsInOrder(['foo', 'baz'])))
            .isARejection(
                which: ['does not have a match for the substring \'foo\'']);
      });
      test('reports when substring is missing following a match', () {
        checkThat(softCheck<String>(
                'foo bar', it()..containsInOrder(['foo', 'baz'])))
            .isARejection(which: [
          'does not have a match for the substring \'baz\'',
          'following the other matches up to character 3'
        ]);
      });
    });

    group('equals', () {
      test('succeeeds for happy case', () {
        checkThat('foo').equals('foo');
      });
      test('succeeeds for equal empty strings', () {
        checkThat('').equals('');
      });
      test('reports extra characters for long string', () {
        checkThat(softCheck<String>('foobar', it()..equals('foo')))
            .isARejection(which: [
          'is too long with unexpected trailing characters:',
          'bar'
        ]);
      });
      test('reports extra characters for long string against empty', () {
        checkThat(softCheck<String>('foo', it()..equals('')))
            .isARejection(which: ['is not the empty string']);
      });
      test('reports truncated extra characters for very long string', () {
        checkThat(
                softCheck<String>('foobar baz more stuff', it()..equals('foo')))
            .isARejection(which: [
          'is too long with unexpected trailing characters:',
          'bar baz mo ...'
        ]);
      });
      test('reports missing characters for short string', () {
        checkThat(softCheck<String>('foo', it()..equals('foobar')))
            .isARejection(which: [
          'is too short with missing trailing characters:',
          'bar'
        ]);
      });
      test('reports missing characters for empty string', () {
        checkThat(softCheck<String>('', it()..equals('foo bar baz')))
            .isARejection(actual: [
          'an empty string'
        ], which: [
          'is missing all expected characters:',
          'foo bar ba ...'
        ]);
      });
      test('reports truncated missing characters for very short string', () {
        checkThat(
                softCheck<String>('foo', it()..equals('foobar baz more stuff')))
            .isARejection(which: [
          'is too short with missing trailing characters:',
          'bar baz mo ...'
        ]);
      });
      test('reports index of different character', () {
        checkThat(softCheck<String>('hit', it()..equals('hat')))
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
                it()..equals('blah blah blah hat blah blah blah')))
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
        checkThat(softCheck<String>('FOOBAR', it()..equalsIgnoringCase('foo')))
            .isARejection(which: [
          'is too long with unexpected trailing characters:',
          'BAR'
        ]);
      });
      test('reports original missing characters for short string', () {
        checkThat(softCheck<String>('FOO', it()..equalsIgnoringCase('fooBAR')))
            .isARejection(which: [
          'is too short with missing trailing characters:',
          'BAR'
        ]);
      });
      test('reports index of different character with original characters', () {
        checkThat(softCheck<String>('HiT', it()..equalsIgnoringCase('hAt')))
            .isARejection(which: [
          'differs at offset 1:',
          'hAt',
          'HiT',
          ' ^',
        ]);
      });
    });

    group('equalsIgnoringWhitespace', () {
      test('allows differing internal whitespace', () {
        checkThat('foo \t\n bar').equalsIgnoringWhitespace('foo bar');
      });
      test('allows extra leading/trailing whitespace', () {
        checkThat(' foo ').equalsIgnoringWhitespace('foo');
      });
      test('allows missing leading/trailing whitespace', () {
        checkThat('foo').equalsIgnoringWhitespace(' foo ');
      });
      test('reports original extra characters for long string', () {
        checkThat(softCheck<String>(
                'foo \t bar \n baz', it()..equalsIgnoringWhitespace('foo bar')))
            .isARejection(which: [
          'is too long with unexpected trailing characters:',
          ' baz'
        ]);
      });
      test('reports original missing characters for short string', () {
        checkThat(softCheck<String>(
                'foo  bar', it()..equalsIgnoringWhitespace('foo bar baz')))
            .isARejection(which: [
          'is too short with missing trailing characters:',
          ' baz'
        ]);
      });
      test('reports index of different character with original characters', () {
        checkThat(softCheck<String>(
                'x  hit  x', it()..equalsIgnoringWhitespace('x hat x')))
            .isARejection(which: [
          'differs at offset 3:',
          'x hat x',
          'x hit x',
          '   ^',
        ]);
      });
    });
  });
}
