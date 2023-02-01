// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/src/collection_equality.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('deepCollectionEquals', () {
    test('allows nested collections with equal elements', () {
      (deepCollectionEquals([
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
      ])).must.beNull();
    });

    test('allows collections inside sets', () {
      (deepCollectionEquals({
        {'a': 1}
      }, {
        {'a': 1}
      })).must.beNull();
    });

    test('allows collections as Map keys', () {
      (deepCollectionEquals([
        {
          {'a': 1}: {'b': 2}
        }
      ], [
        {
          {'a': 1}: {'b': 2}
        }
      ])).must.beNull();
    });

    test('allows conditions in place of elements in lists', () {
      (deepCollectionEquals([
        'a',
        'b'
      ], [
        would()
          ..beA<String>().which(would()
            ..startWith('a')
            ..haveLength.beLessThat(2)),
        would()..beA<String>().startWith('b')
      ])).must.beNull();
    });

    test('allows conditions in place of values in maps', () {
      (deepCollectionEquals([
        {'a': 'b'}
      ], [
        {'a': would()..beA<String>().startWith('b')}
      ])).must.beNull();
    });

    test('allows conditions in place of elements in sets', () {
      (deepCollectionEquals(
              {'b', 'a'}, {'a', would()..beA<String>().startWith('b')}))
          .must
          .beNull();
    });

    test('allows conditions in place of keys in maps', () {
      (deepCollectionEquals(
              {'a': 'b'}, {would()..beA<String>().startWith('a'): 'b'}))
          .must
          .beNull();
    });

    test('reports non-Set elements', () {
      (deepCollectionEquals([
        ['a']
      ], [
        {'a'}
      ])).must.beNonNull().deeplyEqual(['at [<0>] is not a Set']);
    });

    test('reports long iterables', () {
      (deepCollectionEquals([0], [])).must.beNonNull().deeplyEqual([
        'has more elements than expected',
        'expected an iterable with 0 element(s)'
      ]);
    });

    test('reports short iterables', () {
      (deepCollectionEquals([], [0])).must.beNonNull().deeplyEqual([
        'has too few elements',
        'expected an iterable with at least 1 element(s)'
      ]);
    });

    test('reports unequal elements in iterables', () {
      (deepCollectionEquals([0], [1]))
          .must
          .beNonNull()
          .deeplyEqual(['at [<0>] is <0>', 'which does not equal <1>']);
    });

    test('reports unmet conditions in iterables', () {
      (deepCollectionEquals([0], [would()..beA<int>().beGreaterThan(0)]))
          .must
          .beNonNull()
          .deeplyEqual([
        'has an element at [<0>] that:',
        '  Actual: <0>',
        '  which is not greater than <0>'
      ]);
    });

    test('reports unmet conditions in map values', () {
      (deepCollectionEquals(
              {'a': 'b'}, {'a': would()..beA<String>().startWith('a')}))
          .must
          .beNonNull()
          .deeplyEqual([
        "has no entry to match 'a': <A value that:",
        '  is a String',
        "  starts with 'a'>",
      ]);
    });

    test('reports unmet conditions in map keys', () {
      (deepCollectionEquals(
              {'b': 'a'}, {would()..beA<String>().startWith('a'): 'a'}))
          .must
          .beNonNull()
          .deeplyEqual([
        'has no entry to match <A value that:',
        '  is a String',
        "  starts with 'a'>: 'a'",
      ]);
    });

    test('reports recursive lists', () {
      var l = [];
      l.add(l);
      (deepCollectionEquals(l, l))
          .must
          .beNonNull()
          .deeplyEqual(['exceeds the depth limit of 1000']);
    });

    test('reports recursive sets', () {
      var s = <Object>{};
      s.add(s);
      (deepCollectionEquals(s, s))
          .must
          .beNonNull()
          .deeplyEqual(['exceeds the depth limit of 1000']);
    });

    test('reports maps with recursive keys', () {
      var m = <Object, Object>{};
      m[m] = 0;
      (deepCollectionEquals(m, m))
          .must
          .beNonNull()
          .deeplyEqual(['exceeds the depth limit of 1000']);
    });

    test('reports maps with recursive values', () {
      var m = <Object, Object>{};
      m[0] = m;
      (deepCollectionEquals(m, m))
          .must
          .beNonNull()
          .deeplyEqual(['exceeds the depth limit of 1000']);
    });
  });
}
