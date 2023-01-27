// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('StringChecks', () {
    test('contains', () {
      checkThat('bob').contains('bo');
      checkThat('bob').isRejectedBy(it()..contains('kayleb'),
          which: ["Does not contain 'kayleb'"]);
    });
    test('length', () {
      checkThat('bob').length.equals(3);
    });
    test('isEmpty', () {
      checkThat('').isEmpty();
      checkThat('bob').isRejectedBy(it()..isEmpty(), which: ['is not empty']);
    });
    test('isNotEmpty', () {
      checkThat('bob').isNotEmpty();
      checkThat('').isRejectedBy(it()..isNotEmpty(), which: ['is empty']);
    });
    test('startsWith', () {
      checkThat('bob').startsWith('bo');
      checkThat('bob').isRejectedBy(it()..startsWith('kayleb'),
          which: ["does not start with 'kayleb'"]);
    });
    test('endsWith', () {
      checkThat('bob').endsWith('ob');
      checkThat('bob').isRejectedBy(it()..endsWith('kayleb'),
          which: ["does not end with 'kayleb'"]);
    });

    group('matches', () {
      test('succeeds for strings that match', () {
        checkThat('123').matches(RegExp(r'\d\d\d'));
      });
      test('fails for non-matching strings', () {
        checkThat('abc').isRejectedBy(it()..matches(RegExp(r'\d\d\d')),
            which: [r'does not match <RegExp: pattern=\d\d\d flags=>']);
      });
      test('can be described', () {
        checkThat(it<String>()..matches(RegExp(r'\d\d\d')))
            .description
            .deepEquals([r'  matches <RegExp: pattern=\d\d\d flags=>']);
      });
    });

    group('containsInOrder', () {
      test('happy case', () {
        checkThat('foo bar baz').containsInOrder(['foo', 'baz']);
      });
      test('reports when first substring is missing', () {
        checkThat('baz').isRejectedBy(it()..containsInOrder(['foo', 'baz']),
            which: ['does not have a match for the substring \'foo\'']);
      });
      test('reports when substring is missing following a match', () {
        checkThat('foo bar')
            .isRejectedBy(it()..containsInOrder(['foo', 'baz']), which: [
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
        checkThat('foobar').isRejectedBy(it()..equals('foo'),
            which: ['is too long with unexpected trailing characters:', 'bar']);
      });
      test('reports extra characters for long string against empty', () {
        checkThat('foo')
            .isRejectedBy(it()..equals(''), which: ['is not the empty string']);
      });
      test('reports truncated extra characters for very long string', () {
        checkThat('foobar baz more stuff').isRejectedBy(it()..equals('foo'),
            which: [
              'is too long with unexpected trailing characters:',
              'bar baz mo ...'
            ]);
      });
      test('reports missing characters for short string', () {
        checkThat('foo').isRejectedBy(it()..equals('foobar'),
            which: ['is too short with missing trailing characters:', 'bar']);
      });
      test('reports missing characters for empty string', () {
        checkThat('').isRejectedBy(it()..equals('foo bar baz'),
            actual: ['an empty string'],
            which: ['is missing all expected characters:', 'foo bar ba ...']);
      });
      test('reports truncated missing characters for very short string', () {
        checkThat('foo').isRejectedBy(it()..equals('foobar baz more stuff'),
            which: [
              'is too short with missing trailing characters:',
              'bar baz mo ...'
            ]);
      });
      test('reports index of different character', () {
        checkThat('hit').isRejectedBy(it()..equals('hat'), which: [
          'differs at offset 1:',
          'hat',
          'hit',
          ' ^',
        ]);
      });
      test('reports truncated index of different character in large string',
          () {
        checkThat('blah blah blah hit blah blah blah').isRejectedBy(
            it()..equals('blah blah blah hat blah blah blah'),
            which: [
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
        checkThat('FOOBAR').isRejectedBy(it()..equalsIgnoringCase('foo'),
            which: ['is too long with unexpected trailing characters:', 'BAR']);
      });
      test('reports original missing characters for short string', () {
        checkThat('FOO').isRejectedBy(it()..equalsIgnoringCase('fooBAR'),
            which: ['is too short with missing trailing characters:', 'BAR']);
      });
      test('reports index of different character with original characters', () {
        checkThat('HiT').isRejectedBy(it()..equalsIgnoringCase('hAt'), which: [
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
        checkThat('foo \t bar \n baz')
            .isRejectedBy(it()..equalsIgnoringWhitespace('foo bar'), which: [
          'is too long with unexpected trailing characters:',
          ' baz'
        ]);
      });
      test('reports original missing characters for short string', () {
        checkThat('foo  bar').isRejectedBy(
            it()..equalsIgnoringWhitespace('foo bar baz'),
            which: ['is too short with missing trailing characters:', ' baz']);
      });
      test('reports index of different character with original characters', () {
        checkThat('x  hit  x')
            .isRejectedBy(it()..equalsIgnoringWhitespace('x hat x'), which: [
          'differs at offset 3:',
          'x hat x',
          'x hit x',
          '   ^',
        ]);
      });
    });
  });
}
