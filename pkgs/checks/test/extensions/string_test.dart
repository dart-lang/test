// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('StringChecks', () {
    test('contains', () {
      'bob'.must.contain('bo');
      'bob'.must.beRejectedBy(would()..contain('kayleb'),
          which: ["Does not contain 'kayleb'"]);
    });
    test('length', () {
      'bob'.must.haveLength.equal(3);
    });
    test('isEmpty', () {
      ''.must.beEmpty();
      'bob'.must.beRejectedBy(would()..beEmpty(), which: ['is not empty']);
    });
    test('isNotEmpty', () {
      'bob'.must.beNotEmpty();
      ''.must.beRejectedBy(would()..beNotEmpty(), which: ['is empty']);
    });
    test('startsWith', () {
      'bob'.must.startWith('bo');
      'bob'.must.beRejectedBy(would()..startWith('kayleb'),
          which: ["does not start with 'kayleb'"]);
    });
    test('endsWith', () {
      'bob'.must.endWith('ob');
      'bob'.must.beRejectedBy(would()..endWith('kayleb'),
          which: ["does not end with 'kayleb'"]);
    });

    group('matches', () {
      test('succeeds for strings that match', () {
        '123'.must.matchRegex(RegExp(r'\d\d\d'));
      });
      test('fails for non-matching strings', () {
        'abc'.must.beRejectedBy(would()..matchRegex(RegExp(r'\d\d\d')),
            which: [r'does not match <RegExp: pattern=\d\d\d flags=>']);
      });
      test('can be described', () {
        (would<String>()..matchRegex(RegExp(r'\d\d\d')))
            .must
            .haveDescription
            .deeplyEqual([r'  matches <RegExp: pattern=\d\d\d flags=>']);
      });
    });

    group('containsInOrder', () {
      test('happy case', () {
        'foo bar baz'.must.containInOrder(['foo', 'baz']);
      });
      test('reports when first substring is missing', () {
        'baz'.must.beRejectedBy(would()..containInOrder(['foo', 'baz']),
            which: ['does not have a match for the substring \'foo\'']);
      });
      test('reports when substring is missing following a match', () {
        'foo bar'
            .must
            .beRejectedBy(would()..containInOrder(['foo', 'baz']), which: [
          'does not have a match for the substring \'baz\'',
          'following the other matches up to character 3'
        ]);
      });
    });

    group('equals', () {
      test('succeeeds for happy case', () {
        'foo'.must.equal('foo');
      });
      test('succeeeds for equal empty strings', () {
        ''.must.equal('');
      });
      test('reports extra characters for long string', () {
        'foobar'.must.beRejectedBy(would()..equal('foo'),
            which: ['is too long with unexpected trailing characters:', 'bar']);
      });
      test('reports extra characters for long string against empty', () {
        'foo'.must.beRejectedBy(would()..equal(''),
            which: ['is not the empty string']);
      });
      test('reports truncated extra characters for very long string', () {
        'foobar baz more stuff'.must.beRejectedBy(would()..equal('foo'),
            which: [
              'is too long with unexpected trailing characters:',
              'bar baz mo ...'
            ]);
      });
      test('reports missing characters for short string', () {
        'foo'.must.beRejectedBy(would()..equal('foobar'),
            which: ['is too short with missing trailing characters:', 'bar']);
      });
      test('reports missing characters for empty string', () {
        ''.must.beRejectedBy(would()..equal('foo bar baz'),
            actual: ['an empty string'],
            which: ['is missing all expected characters:', 'foo bar ba ...']);
      });
      test('reports truncated missing characters for very short string', () {
        'foo'.must.beRejectedBy(would()..equal('foobar baz more stuff'),
            which: [
              'is too short with missing trailing characters:',
              'bar baz mo ...'
            ]);
      });
      test('reports index of different character', () {
        'hit'.must.beRejectedBy(would()..equal('hat'), which: [
          'differs at offset 1:',
          'hat',
          'hit',
          ' ^',
        ]);
      });
      test('reports truncated index of different character in large string',
          () {
        'blah blah blah hit blah blah blah'.must.beRejectedBy(
            would()..equal('blah blah blah hat blah blah blah'),
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
        'FOO'.must.equalIgnoringCase('foo');
        'foo'.must.equalIgnoringCase('FOO');
      });
      test('reports original extra characters for long string', () {
        'FOOBAR'.must.beRejectedBy(would()..equalIgnoringCase('foo'),
            which: ['is too long with unexpected trailing characters:', 'BAR']);
      });
      test('reports original missing characters for short string', () {
        'FOO'.must.beRejectedBy(would()..equalIgnoringCase('fooBAR'),
            which: ['is too short with missing trailing characters:', 'BAR']);
      });
      test('reports index of different character with original characters', () {
        'HiT'.must.beRejectedBy(would()..equalIgnoringCase('hAt'), which: [
          'differs at offset 1:',
          'hAt',
          'HiT',
          ' ^',
        ]);
      });
    });

    group('equalsIgnoringWhitespace', () {
      test('allows differing internal whitespace', () {
        'foo \t\n bar'.must.equalIgnoringQhitespace('foo bar');
      });
      test('allows extra leading/trailing whitespace', () {
        ' foo '.must.equalIgnoringQhitespace('foo');
      });
      test('allows missing leading/trailing whitespace', () {
        'foo'.must.equalIgnoringQhitespace(' foo ');
      });
      test('reports original extra characters for long string', () {
        'foo \t bar \n baz'
            .must
            .beRejectedBy(would()..equalIgnoringQhitespace('foo bar'), which: [
          'is too long with unexpected trailing characters:',
          ' baz'
        ]);
      });
      test('reports original missing characters for short string', () {
        'foo  bar'.must.beRejectedBy(
            would()..equalIgnoringQhitespace('foo bar baz'),
            which: ['is too short with missing trailing characters:', ' baz']);
      });
      test('reports index of different character with original characters', () {
        'x  hit  x'
            .must
            .beRejectedBy(would()..equalIgnoringQhitespace('x hat x'), which: [
          'differs at offset 3:',
          'x hat x',
          'x hit x',
          '   ^',
        ]);
      });
    });
  });
}
