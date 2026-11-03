// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:matcher/expect.dart';
import 'package:test/test.dart' show TestFailure, group, test;

import 'test_utils.dart';

void main() {
  test('isTrue', () {
    shouldPass(true, isTrue);
    shouldFail(false, isTrue, 'Expected: true Actual: <false>');
  });

  test('isFalse', () {
    shouldPass(false, isFalse);
    shouldFail(10, isFalse, 'Expected: false Actual: <10>');
    shouldFail(true, isFalse, 'Expected: false Actual: <true>');
  });

  test('isNull', () {
    shouldPass(null, isNull);
    shouldFail(false, isNull, 'Expected: null Actual: <false>');
  });

  test('isNotNull', () {
    shouldPass(false, isNotNull);
    shouldFail(null, isNotNull, 'Expected: not null Actual: <null>');
  });

  test('isNaN', () {
    shouldPass(double.nan, isNaN);
    shouldFail(3.1, isNaN, 'Expected: NaN Actual: <3.1>');
    shouldFail('not a num', isNaN, endsWith('not an <Instance of \'num\'>'));
  });

  test('isNotNaN', () {
    shouldPass(3.1, isNotNaN);
    shouldFail(double.nan, isNotNaN, 'Expected: not NaN Actual: <NaN>');
    shouldFail('not a num', isNotNaN, endsWith('not an <Instance of \'num\'>'));
  });

  test('same', () {
    var a = <Object?, Object?>{};
    var b = <Object?, Object?>{};
    shouldPass(a, same(a));
    shouldFail(b, same(a), 'Expected: same instance as {} Actual: {}');
  });

  test('equals', () {
    var a = <Object?, Object?>{};
    var b = <Object?, Object?>{};
    shouldPass(a, equals(a));
    shouldPass(a, equals(b));
  });

  test('equals with null', () {
    Object? a; // null
    var b = <Object?, Object?>{};
    shouldPass(a, equals(a));
    shouldFail(
      a,
      equals(b),
      'Expected: {} Actual: <null> Which: expected a map',
    );
    shouldFail(b, equals(a), 'Expected: <null> Actual: {}');
  });

  test('equals with a set', () {
    var numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    var set1 = numbers.toSet();
    numbers.shuffle();
    var set2 = numbers.toSet();

    shouldPass(set2, equals(set1));
    shouldPass(numbers, equals(set1));
    shouldFail(
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      equals(set1),
      matches(
        r'Expected: .*:\[1, 2, 3, 4, 5, 6, 7, 8, 9, 10\]'
        r'  Actual: \[1, 2, 3, 4, 5, 6, 7, 8, 9\]'
        r'   Which: does not contain <10>',
      ),
    );
    shouldFail(
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
      equals(set1),
      matches(
        r'Expected: .*:\[1, 2, 3, 4, 5, 6, 7, 8, 9, 10\]'
        r'  Actual: \[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11\]'
        r'   Which: larger than expected',
      ),
    );
  });

  test('equals with a set requires distinct matching elements', () {
    shouldFail(
      {1, -1},
      equals({greaterThan(0), equals(1)}),
      endsWith(
        'cannot pair each expected element with a distinct actual element',
      ),
    );
    shouldFail(
      {
        [1],
        [2],
      },
      equals({
        [1],
        [1],
      }),
      endsWith(
        'cannot pair each expected element with a distinct actual element',
      ),
    );
    shouldFail(
      {
        [1],
      },
      equals({
        [1],
        [1],
      }),
      endsWith('smaller than expected'),
    );
  });

  test('equals with a set reassigns overlapping matches', () {
    shouldPass({1, 2}, equals({greaterThan(0), equals(1)}));
    shouldPass({2, 1}, equals({greaterThan(0), equals(1)}));
    shouldPass([1, 2, 1], equals({greaterThan(0), equals(1)}));
    shouldPass({1, 2, 3}, equals({lessThan(3), greaterThan(1), equals(1)}));
  });

  test('equals with a set compares each pair at most once', () {
    var calls = <String, int>{};
    Matcher countingMatcher(int index, bool Function(int) accepts) =>
        predicate<int>((item) {
          var key = '$index:$item';
          calls.update(key, (count) => count + 1, ifAbsent: () => 1);
          return accepts(item);
        });
    shouldPass(
      {1, 2, 3},
      equals({
        countingMatcher(0, (item) => item < 3),
        countingMatcher(1, (item) => item > 1),
        countingMatcher(2, (item) => item == 1),
      }),
    );
    expect(calls.values, everyElement(1));
  });

  test('equals with unequal set sizes scans only for membership', () {
    var calls = 0;
    var matcher = equals({
      for (var i = 0; i < 64; i++)
        predicate<int>((item) {
          calls++;
          return true;
        }),
    });
    for (var size in [32, 4096]) {
      calls = 0;
      var actual = List.generate(size, (i) => i);
      var state = <Object?, Object?>{};
      expect(matcher.matches(actual, state), isFalse);
      expect(calls, 64);
      expect(
        matcher
            .describeMismatch(actual, StringDescription(), state, false)
            .toString(),
        size < 64 ? 'smaller than expected' : 'larger than expected',
      );
    }
    // Missing elements still take precedence over either size diagnostic.
    shouldFail({1, 2, 3}, equals({4}), endsWith('does not contain <4>'));
    shouldFail({1}, equals({1, 2}), endsWith('does not contain <2>'));
  });

  test('equals with a wide shallow set pairs structural duplicates', () {
    shouldPass(
      {
        for (var i = 0; i < 256; i++) [0],
      },
      equals({
        for (var i = 0; i < 256; i++) [0],
      }),
    );
  });

  test('equals with a set reassigns a long chain without repeating pairs', () {
    const size = 128;
    var calls = <String>{};
    var expected = <Matcher>{
      for (var i = 0; i < size - 1; i++)
        predicate<int>((item) {
          expect(calls.add('$i:$item'), isTrue);
          return item == i || item == i + 1;
        }),
      equals(0),
    };
    // The last element displaces every earlier assignment along the chain.
    shouldPass(List.generate(size, (i) => i), equals(expected));
  });

  test('equals with a set rejects a collective shortage of candidates', () {
    shouldFail(
      {0, 1, 2, 3},
      equals({lessThan(2), lessThan(2), lessThan(2), anything}),
      endsWith(
        'cannot pair each expected element with a distinct actual element',
      ),
    );
  });

  test('equals reports the location of a nested set pairing failure', () {
    shouldFail(
      [
        {
          'values': {1, -1},
        },
      ],
      equals([
        {
          'values': {greaterThan(0), equals(1)},
        },
      ]),
      allOf(
        contains("at location [0]['values']"),
        endsWith(
          'cannot pair each expected element with a distinct actual element',
        ),
      ),
    );
  });

  test('equals with a set pairs nested matchers', () {
    var listMatcher = equals({
      [greaterThan(0)],
      [equals(1)],
    });
    shouldPass({
      [1],
      [2],
    }, listMatcher);
    shouldFail(
      {
        [1],
        [-1],
      },
      listMatcher,
      endsWith(
        'cannot pair each expected element with a distinct actual element',
      ),
    );
    var mapMatcher = equals({
      {'value': greaterThan(0)},
      {'value': equals(1)},
    });
    shouldPass({
      {'value': 1},
      {'value': 2},
    }, mapMatcher);
    shouldFail(
      {
        {'value': 1},
        {'value': -1},
      },
      mapMatcher,
      endsWith(
        'cannot pair each expected element with a distinct actual element',
      ),
    );
  });

  test('equals with NaN', () {
    final a = double.nan;
    final b = 0;
    shouldPass(a, equals(a));
    shouldFail(a, equals(b), 'Expected: <0> Actual: <NaN>');
    shouldFail(b, equals(a), 'Expected: <NaN> Actual: <0>');
  });

  test('equals with NaN in a collection', () {
    final a = {double.nan};
    final b = {0};
    shouldPass(a, equals(a));
    shouldFail(
      a,
      equals(b),
      'Expected: Set:[0] Actual: Set:[NaN] '
      'Which: does not contain <0>',
    );
    shouldFail(
      b,
      equals(a),
      'Expected: Set:[NaN] Actual: Set:[0] '
      'Which: does not contain <NaN>',
    );
  });

  test('equals that throw expose the exception', () {
    expect(
      () {
        expect(0, isNot(equals(_ThrowingEquals())));
      },
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          contains(_ThrowingEquals.message),
        ),
      ),
    );
  });

  test('anything', () {
    var a = <Object?, Object?>{};
    shouldPass(0, anything);
    shouldPass(null, anything);
    shouldPass(a, anything);
    shouldFail(a, isNot(anything), 'Expected: not anything Actual: {}');
  });

  test('returnsNormally', () {
    shouldPass(doesNotThrow, returnsNormally);
    shouldFail(
      doesThrow,
      returnsNormally,
      matches(
        r'Expected: return normally'
        r'  Actual: <Closure.*>'
        r'   Which: threw StateError:<Bad state: X>',
      ),
    );
    shouldFail(
      'not a function',
      returnsNormally,
      contains('not an <Instance of \'Function\'>'),
    );
  });

  test('hasLength', () {
    var a = <Object?, Object?>{};
    var b = <Object?>[];
    shouldPass(a, hasLength(0));
    shouldPass(b, hasLength(0));
    shouldPass('a', hasLength(1));
    shouldFail(
      0,
      hasLength(0),
      'Expected: an object with length of <0> '
      'Actual: <0> '
      'Which: has no length property',
    );

    b.add(0);
    shouldPass(b, hasLength(1));
    shouldFail(
      b,
      hasLength(2),
      'Expected: an object with length of <2> '
      'Actual: [0] '
      'Which: has length of <1>',
    );

    b.add(0);
    shouldFail(
      b,
      hasLength(1),
      'Expected: an object with length of <1> '
      'Actual: [0, 0] '
      'Which: has length of <2>',
    );
    shouldPass(b, hasLength(2));
  });

  test('scalar type mismatch', () {
    shouldFail(
      'error',
      equals(5.1),
      'Expected: <5.1> '
          "Actual: 'error'",
    );
  });

  test('nested type mismatch', () {
    shouldFail(
      ['error'],
      equals([5.1]),
      'Expected: [5.1] '
      "Actual: ['error'] "
      "Which: at location [0] is 'error' instead of <5.1>",
    );
  });

  test('doubly-nested type mismatch', () {
    shouldFail(
      [
        ['error'],
      ],
      equals([
        [5.1],
      ]),
      'Expected: [[5.1]] '
      "Actual: [['error']] "
      "Which: at location [0][0] is 'error' instead of <5.1>",
    );
  });

  test('doubly nested inequality', () {
    var actual1 = [
      ['foo', 'bar'],
      ['foo'],
      3,
      <Object?>[],
    ];
    var expected1 = [
      ['foo', 'bar'],
      ['foo'],
      4,
      <Object?>[],
    ];
    var reason1 =
        "Expected: [['foo', 'bar'], ['foo'], 4, []] "
        "Actual: [['foo', 'bar'], ['foo'], 3, []] "
        'Which: at location [2] is <3> instead of <4>';

    var actual2 = [
      ['foo', 'barry'],
      ['foo'],
      4,
      <Object?>[],
    ];
    var expected2 = [
      ['foo', 'bar'],
      ['foo'],
      4,
      <Object?>[],
    ];
    var reason2 =
        "Expected: [['foo', 'bar'], ['foo'], 4, []] "
        "Actual: [['foo', 'barry'], ['foo'], 4, []] "
        "Which: at location [0][1] is 'barry' instead of 'bar'";

    var actual3 = [
      ['foo', 'bar'],
      ['foo'],
      4,
      {'foo': 'bar'},
    ];
    var expected3 = [
      ['foo', 'bar'],
      ['foo'],
      4,
      {'foo': 'barry'},
    ];
    var reason3 =
        "Expected: [['foo', 'bar'], ['foo'], 4, {'foo': 'barry'}] "
        "Actual: [['foo', 'bar'], ['foo'], 4, {'foo': 'bar'}] "
        "Which: at location [3]['foo'] is 'bar' instead of 'barry'";

    shouldFail(actual1, equals(expected1), reason1);
    shouldFail(actual2, equals(expected2), reason2);
    shouldFail(actual3, equals(expected3), reason3);
  });

  group('Predicate Matchers', () {
    test('isInstanceOf', () {
      shouldFail(
        0,
        predicate((x) => x is String, 'an instance of String'),
        'Expected: an instance of String Actual: <0>',
      );
      shouldPass('cow', predicate((x) => x is String, 'an instance of String'));

      shouldFail(
        0,
        predicate((bool x) => x, 'bool value is true'),
        endsWith("not an <Instance of 'bool'>"),
      );
    });
  });

  group('wrapMatcher', () {
    test('wraps a predicate which allows a nullable argument', () {
      final matcher = wrapMatcher((_) => true);
      shouldPass(null, matcher);
    });

    test('wraps a predicate which has a typed argument check', () {
      final matcher = wrapMatcher((int _) => true);
      shouldPass(1, matcher);
    });
  });
}

class _ThrowingEquals implements Exception {
  static const message = 'Exception thrown in operator ==';
  @override
  bool operator ==(Object other) {
    throw this;
  }

  @override
  int get hashCode => super.hashCode + 1;

  @override
  String toString() => message;
}
