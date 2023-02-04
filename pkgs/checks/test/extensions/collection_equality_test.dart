// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/src/collection_equality.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('deepCollectionEquals', () {
    test('allows nested collections with equal elements', () {
      check(deepCollectionEquals([
        'a',
        {'b': 1},
        {'c', 'd'},
        [
          ['e']
        ],
      ], [
        'a',
        {'b': 1},
        {'c', 'd'},
        [
          ['e']
        ],
      ])).isNull();
    });

    test('allows collections inside sets', () {
      check(deepCollectionEquals({
        {'a': 1}
      }, {
        {'a': 1}
      })).isNull();
    });

    test('allows collections as Map keys', () {
      check(deepCollectionEquals([
        {
          {'a': 1}: {'b': 2}
        }
      ], [
        {
          {'a': 1}: {'b': 2}
        }
      ])).isNull();
    });

    test('allows conditions in place of elements in lists', () {
      check(deepCollectionEquals([
        'a',
        'b'
      ], [
        it()
          ..isA<String>().which(it()
            ..startsWith('a')
            ..length.isLessThan(2)),
        it()..isA<String>().startsWith('b')
      ])).isNull();
    });

    test('allows conditions in place of values in maps', () {
      check(deepCollectionEquals([
        {'a': 'b'}
      ], [
        {'a': it()..isA<String>().startsWith('b')}
      ])).isNull();
    });

    test('allows conditions in place of elements in sets', () {
      check(deepCollectionEquals(
          {'b', 'a'}, {'a', it()..isA<String>().startsWith('b')})).isNull();
    });

    test('allows conditions in place of keys in maps', () {
      check(deepCollectionEquals(
          {'a': 'b'}, {it()..isA<String>().startsWith('a'): 'b'})).isNull();
    });

    test('reports non-Set elements', () {
      check(deepCollectionEquals([
        ['a']
      ], [
        {'a'}
      ])).isNotNull().deepEquals(['at [<0>] is not a Set']);
    });

    test('reports long iterables', () {
      check(deepCollectionEquals([0], [])).isNotNull().deepEquals([
        'has more elements than expected',
        'expected an iterable with 0 element(s)'
      ]);
    });

    test('reports short iterables', () {
      check(deepCollectionEquals([], [0])).isNotNull().deepEquals([
        'has too few elements',
        'expected an iterable with at least 1 element(s)'
      ]);
    });

    test('reports unequal elements in iterables', () {
      check(deepCollectionEquals([0], [1]))
          .isNotNull()
          .deepEquals(['at [<0>] is <0>', 'which does not equal <1>']);
    });

    test('reports unmet conditions in iterables', () {
      check(deepCollectionEquals([0], [it()..isA<int>().isGreaterThan(0)]))
          .isNotNull()
          .deepEquals([
        'has an element at [<0>] that:',
        '  Actual: <0>',
        '  which is not greater than <0>'
      ]);
    });

    test('reports unmet conditions in map values', () {
      check(deepCollectionEquals(
              {'a': 'b'}, {'a': it()..isA<String>().startsWith('a')}))
          .isNotNull()
          .deepEquals([
        "has no entry to match 'a': <A value that:",
        '  is a String',
        "  starts with 'a'>",
      ]);
    });

    test('reports unmet conditions in map keys', () {
      check(deepCollectionEquals(
              {'b': 'a'}, {it()..isA<String>().startsWith('a'): 'a'}))
          .isNotNull()
          .deepEquals([
        'has no entry to match <A value that:',
        '  is a String',
        "  starts with 'a'>: 'a'",
      ]);
    });

    test('reports recursive lists', () {
      var l = [];
      l.add(l);
      check(deepCollectionEquals(l, l))
          .isNotNull()
          .deepEquals(['exceeds the depth limit of 1000']);
    });

    test('reports recursive sets', () {
      var s = <Object>{};
      s.add(s);
      check(deepCollectionEquals(s, s))
          .isNotNull()
          .deepEquals(['exceeds the depth limit of 1000']);
    });

    test('reports maps with recursive keys', () {
      var m = <Object, Object>{};
      m[m] = 0;
      check(deepCollectionEquals(m, m))
          .isNotNull()
          .deepEquals(['exceeds the depth limit of 1000']);
    });

    test('reports maps with recursive values', () {
      var m = <Object, Object>{};
      m[0] = m;
      check(deepCollectionEquals(m, m))
          .isNotNull()
          .deepEquals(['exceeds the depth limit of 1000']);
    });
  });
}
