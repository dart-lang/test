// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

Iterable<int> get _testIterable => Iterable.generate(2, (i) => i);

void main() {
  test('length', () {
    check(_testIterable).length.equals(2);
  });

  group('first', () {
    test('succeeds for happy case', () {
      check(_testIterable).first.equals(0);
    });
    test('rejects empty iterable', () {
      check(
        <Object>[],
      ).isRejectedBy(.it()..first.equals(0), which: ['has no elements']);
    });
  });

  group('last', () {
    test('succeeds for happy case', () {
      check(_testIterable).last.equals(1);
    });
    test('rejects empty iterable', () {
      check(
        <Object>[],
      ).isRejectedBy(.it()..last.equals(0), which: ['has no elements']);
    });
  });

  group('single', () {
    test('succeeds for happy case', () {
      check([42]).single.equals(42);
    });
    test('rejects empty iterable', () {
      check(
        <Object>[],
      ).isRejectedBy(.it()..single.equals(0), which: ['has no elements']);
    });
    test('rejects iterable with too many elements', () {
      check(_testIterable).isRejectedBy(
        .it()..single.equals(0),
        which: ['has more than one element'],
      );
    });
  });

  test('isEmpty', () {
    check(<Object>[]).isEmpty;
    check(_testIterable).isRejectedBy(.it()..isEmpty, which: ['is not empty']);
  });

  test('isNotEmpty', () {
    check(_testIterable).isNotEmpty;
    check(
      const Iterable<int>.empty(),
    ).isRejectedBy(.it()..isNotEmpty, which: ['is empty']);
  });

  test('contains', () {
    check(_testIterable).contains(0);
    check(
      _testIterable,
    ).isRejectedBy(.it()..contains(2), which: ['does not contain <2>']);
  });
  test('any', () {
    check(_testIterable).any(.it()..equals(1));
    check(_testIterable).isRejectedBy(
      .it()..any(.it()..equals(2)),
      which: ['contains no matching element'],
    );
  });

  group('containsInOrder', () {
    test('succeeds for happy case', () {
      check([0, 1, 0, 2, 0, 3]).containsInOrder([1, 2, 3]);
    });
    test('can use Condition<dynamic>', () {
      check(
        [0, 1],
      ).containsInOrder([Condition.it<dynamic>()..isA<int>().isGreaterThan(0)]);
    });
    test('can use Condition<T>', () {
      check([0, 1]).containsInOrder([Condition.it<int>()..isGreaterThan(0)]);
    });
    test('fails for not found elements by equality', () async {
      check([0]).isRejectedBy(
        .it()..containsInOrder([1]),
        which: [
          'did not have an element matching the expectation at index 0 <1>',
        ],
      );
    });
    test('fails for not found elements by condition', () async {
      check([0]).isRejectedBy(
        .it()..containsInOrder([
          Condition.it<dynamic>()..isA<int>().isGreaterThan(0),
        ]),
        which: [
          'did not have an element matching the expectation at index 0 '
              '<A value that:',
          '  is a int',
          '  is greater than <0>>',
        ],
      );
    });
    test('can be described', () {
      check(
        Condition.it<Iterable>()..containsInOrder([1, 2, 3]),
      ).hasSyncDescription().deepEquals(['  contains, in order: [1, 2, 3]']);
      check(
        Condition.it<Iterable>()
          ..containsInOrder([1, Condition.it<dynamic>()..equals(2)]),
      ).hasSyncDescription().deepEquals([
        '  contains, in order: [1,',
        '  <A value that:',
        '    equals <2>>]',
      ]);
    });
  });

  group('containsMatchingInOrder', () {
    test('succeeds for happy case', () {
      check([0, 1, 0, 2, 0, 3]).containsMatchingInOrder([
        .it()..isLessThan(2),
        .it()..isLessThan(3),
        .it()..isLessThan(4),
      ]);
    });
    test('fails for not found elements', () async {
      check([0]).isRejectedBy(
        .it()..containsMatchingInOrder([.it()..isGreaterThan(0)]),
        which: [
          'did not have an element matching the expectation at index 0 '
              '<A value that:',
          '  is greater than <0>>',
        ],
      );
    });
    test('can be described', () {
      check(
        Condition.it<Iterable<int>>()..containsMatchingInOrder([
          .it()..isLessThan(2),
          .it()..isLessThan(3),
          .it()..isLessThan(4),
        ]),
      ).hasSyncDescription().deepEquals([
        '  contains, in order: [<A value that:',
        '    is less than <2>>,',
        '  <A value that:',
        '    is less than <3>>,',
        '  <A value that:',
        '    is less than <4>>]',
      ]);
      check(
        Condition.it<Iterable<int>>()
          ..containsMatchingInOrder([.it()..equals(1), .it()..equals(2)]),
      ).hasSyncDescription().deepEquals([
        '  contains, in order: [<A value that:',
        '    equals <1>>,',
        '  <A value that:',
        '    equals <2>>]',
      ]);
    });
  });

  group('containsEqualInOrder', () {
    test('succeeds for happy case', () {
      check([0, 1, 0, 2, 0, 3]).containsEqualInOrder([1, 2, 3]);
    });
    test('fails for not found elements', () async {
      check([0]).isRejectedBy(
        .it()..containsEqualInOrder([1]),
        which: [
          'did not have an element equal to the expectation at index 0 <1>',
        ],
      );
    });
    test('can be described', () {
      check(
        Condition.it<Iterable<int>>()..containsEqualInOrder([1, 2, 3]),
      ).hasSyncDescription().deepEquals(['  contains, in order: [1, 2, 3]']);
      check(
        Condition.it<Iterable<int>>()..containsEqualInOrder([1, 2]),
      ).hasSyncDescription().deepEquals(['  contains, in order: [1, 2]']);
    });
  });
  group('every', () {
    test('succeeds for the happy path', () {
      check(_testIterable).every(.it()..isGreaterOrEqual(-1));
    });

    test('includes details of first failing element', () async {
      check(_testIterable).isRejectedBy(
        .it()..every(.it()..isLessThan(0)),
        which: [
          'has an element at index 0 that:',
          '  Actual: <0>',
          '  Which: is not less than <0>',
        ],
      );
    });

    test('includes the property for a collapsed nested failure', () {
      check([_Foo('foo')]).isRejectedBy(
        .it()..every(.it()..field.equals('bar')),
        actual: ["[Instance of '_Foo']"],
        which: [
          'has an element at index 0 that:',
          "  Actual: has field: 'foo'",
          '  Which: differs at offset 0:',
          '    bar',
          '    foo',
          '    ^',
        ],
      );
    });

    test('includes the property when only the actual collapses', () {
      check([_Foo('foo')]).isRejectedBy(
        .it()..every(
          .it()
            ..field.which(
              .it()
                ..startsWith('f')
                ..endsWith('x'),
            ),
        ),
        actual: ["[Instance of '_Foo']"],
        which: [
          'has an element at index 0 that:',
          "  Actual: has field: 'foo'",
          "  Which: does not end with 'x'",
        ],
      );
    });

    test('includes passing clauses before a failing clause', () {
      check([_Foo('foo')]).isRejectedBy(
        .it()..every(
          .it()
            ..field.equals('foo')
            ..field.length.equals(4),
        ),
        actual: ["[Instance of '_Foo']"],
        which: [
          'has an element at index 0 that:',
          "    has field: 'foo'",
          '    has field that has length: <3>',
          '    Which: is not equal',
        ],
      );
    });

    test('describes a rejected guard within the condition', () {
      check([_Wrapper(123)]).isRejectedBy(
        .it()..every(.it()..value.isA<_Foo>().field.equals('bar')),
        actual: ["[Instance of '_Wrapper']"],
        which: [
          'has an element at index 0 that:',
          '  Actual: has value: <123>',
          '  Which: is a int',
        ],
      );
    });
  });

  group('unorderedEquals', () {
    test('success for happy case', () {
      check(_testIterable).unorderedEquals(_testIterable.toList().reversed);
    });

    test('reports unmatched elements', () {
      check(_testIterable).isRejectedBy(
        .it()..unorderedEquals(_testIterable.followedBy([42, 100])),
        which: [
          'has no element equal to the expected element at index 2: <42>',
          'or 1 other elements',
        ],
      );
    });

    test('reports unexpected elements', () {
      check(_testIterable.followedBy([42, 100])).isRejectedBy(
        .it()..unorderedEquals(_testIterable),
        which: [
          'has an unexpected element at index 2: <42>',
          'and 1 other unexpected elements',
        ],
      );
    });
  });

  group('unorderedMatches', () {
    test('success for happy case', () {
      check(_testIterable).unorderedMatches(
        _testIterable.toList().reversed.map((i) => .it()..equals(i)),
      );
    });

    test('reports unmatched elements', () {
      check(_testIterable).isRejectedBy(
        .it()..unorderedMatches(
          _testIterable.followedBy([42, 100]).map((i) => .it()..equals(i)),
        ),
        which: [
          'has no element matching the condition at index 2:',
          '  equals <42>',
          'or 1 other conditions',
        ],
      );
    });

    test('reports unexpected elements', () {
      check(_testIterable.followedBy([42, 100])).isRejectedBy(
        .it()..unorderedMatches(_testIterable.map((i) => .it()..equals(i))),
        which: [
          'has an unmatched element at index 2: <42>',
          'and 1 other unmatched elements',
        ],
      );
    });
  });

  group('pairwiseMatches', () {
    test('succeeds for the happy path', () {
      check(_testIterable).pairwiseMatches(
        [1, 2],
        (expected) => .it()..isLessThan(expected),
        'is less than',
      );
    });
    test('fails for mismatched element', () async {
      check(_testIterable).isRejectedBy(
        .it()..pairwiseMatches(
          [1, 1],
          (expected) => .it()..isLessThan(expected),
          'is less than',
        ),
        which: [
          'does not have an element at index 1 that:',
          '  is less than <1>',
          '  Actual: <1>',
          '  Which: is not less than <1>',
        ],
      );
    });
    test('includes the property for a nested failure', () {
      check([_Foo('foo')]).isRejectedBy(
        .it()..pairwiseMatches(
          ['bar'],
          (expected) => .it()..field.equals(expected),
          'has field',
        ),
        actual: ["[Instance of '_Foo']"],
        which: [
          'does not have an element at index 0 that:',
          "  has field: 'bar'",
          "  Actual: has field: 'foo'",
          '  Which: differs at offset 0:',
          '    bar',
          '    foo',
          '    ^',
        ],
      );
    });
    test('fails for too few elements', () {
      check(_testIterable).isRejectedBy(
        .it()..pairwiseMatches(
          [1, 2, 3],
          (expected) => .it()..isLessThan(expected),
          'is less than',
        ),
        which: [
          'has too few elements, there is no element to match at index 2',
        ],
      );
    });
    test('fails for too many elements', () {
      check(_testIterable).isRejectedBy(
        .it()..pairwiseMatches(
          [1],
          (expected) => .it()..isLessThan(expected),
          'is less than',
        ),
        which: ['has too many elements, expected exactly 1'],
      );
    });
  });
}

class _Foo {
  final String field;
  _Foo(this.field);
}

class _Wrapper {
  final Object? value;
  _Wrapper(this.value);
}

extension on Subject<_Foo> {
  Subject<String> get field => has((f) => f.field, 'field');
}

extension on Subject<_Wrapper> {
  Subject<Object?> get value => has((w) => w.value, 'value');
}
