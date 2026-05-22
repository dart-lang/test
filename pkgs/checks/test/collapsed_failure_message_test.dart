// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:test_api/hooks.dart' show TestFailure;

void main() {
  group('collapsed failures', () {
    test('simple equals', () {
      check(() {
        check(1).equals(2);
      }).throwsFailure().equals('''
Expected: <2>
Actual: <1>
Which: is not equal''');
    });

    test('nested property equals', () {
      final foo = Foo('foo');
      check(() {
        check(foo).someField.equals('bar');
      }).throwsFailure().equals('''
Expected: a Foo that has someField: 'bar'
Actual: a Foo that has someField: 'foo'
Which: differs at offset 0:
  bar
  foo
  ^''');
    });

    test('deepEquals small collection collapses', () {
      check(() {
        check([1]).deepEquals([2]);
      }).throwsFailure().equals('''
Expected: [2]
Actual: [1]
Which: at [<0>] is <1>
which does not equal <2>''');
    });

    test('deepEquals large collection does not collapse', () {
      final largeList1 = Iterable.generate(30, (i) => i).toList();
      final largeList2 = Iterable.generate(30, (i) => i == 0 ? 1 : i).toList();
      check(() {
        check(largeList1).deepEquals(largeList2);
      }).throwsFailure().startsWith('''
Expected: a List<int> that:
  is deeply equal to [1,
  1,
  2,''');
    });

    test('async completes to equal', () async {
      final future = Future.value(1);
      final checkFuture = check(future).completes((it) => it.equals(2));
      await check(checkFuture).throws<TestFailure>(
        (it) => it.has((f) => f.message, 'message').isNotNull().equals('''
Expected: a Future<int> that completes to <2>
Actual: a Future<int> that completes to <1>
Which: is not equal'''),
      );
    });

    group('core checks', () {
      test('isTrue', () {
        check(() {
          check(false).isTrue();
        }).throwsFailure().equals('''
Expected: true
Actual: <false>''');
      });

      test('isFalse', () {
        check(() {
          check(true).isFalse();
        }).throwsFailure().equals('''
Expected: false
Actual: <true>''');
      });

      test('isNull', () {
        check(() {
          check(1).isNull();
        }).throwsFailure().equals('''
Expected: null
Actual: <1>''');
      });

      test('isGreaterThan', () {
        check(() {
          check(1).isGreaterThan(2);
        }).throwsFailure().equals('''
Expected: a value > <2>
Actual: <1>
Which: is not greater than <2>''');
      });

      test('isGreaterOrEqual', () {
        check(() {
          check(1).isGreaterOrEqual(2);
        }).throwsFailure().equals('''
Expected: a value >= <2>
Actual: <1>
Which: is not greater than or equal to <2>''');
      });

      test('isLessThan', () {
        check(() {
          check(2).isLessThan(1);
        }).throwsFailure().equals('''
Expected: a value < <1>
Actual: <2>
Which: is not less than <1>''');
      });

      test('isLessOrEqual', () {
        check(() {
          check(2).isLessOrEqual(1);
        }).throwsFailure().equals('''
Expected: a value <= <1>
Actual: <2>
Which: is not less than or equal to <1>''');
      });

      test('identicalTo', () {
        check(() {
          check(1).identicalTo(2);
        }).throwsFailure().equals('''
Expected: <2>
Actual: <1>
Which: is not identical''');
      });
    });

    group('math checks', () {
      test('isNaN', () {
        check(() {
          check(1).isNaN();
        }).throwsFailure().equals('''
Expected: NaN
Actual: <1>''');
      });

      test('isNotNaN', () {
        check(() {
          check(double.nan).isNotNaN();
        }).throwsFailure().equals('''
Expected: a number (not NaN)
Actual: <NaN>''');
      });

      test('isNegative', () {
        check(() {
          check(1).isNegative();
        }).throwsFailure().equals('''
Expected: a negative number
Actual: <1>
Which: is not negative''');
      });

      test('isNotNegative', () {
        check(() {
          check(-1).isNotNegative();
        }).throwsFailure().equals('''
Expected: a non-negative number
Actual: <-1>
Which: is negative''');
      });

      test('isFinite', () {
        check(() {
          check(double.infinity).isFinite();
        }).throwsFailure().equals('''
Expected: a finite number
Actual: <Infinity>
Which: is not finite''');
      });

      test('isNotFinite', () {
        check(() {
          check(1).isNotFinite();
        }).throwsFailure().equals('''
Expected: a non-finite number
Actual: <1>
Which: is finite''');
      });

      test('isInfinite', () {
        check(() {
          check(1).isInfinite();
        }).throwsFailure().equals('''
Expected: an infinite number
Actual: <1>
Which: is not infinite''');
      });

      test('isNotInfinite', () {
        check(() {
          check(double.infinity).isNotInfinite();
        }).throwsFailure().equals('''
Expected: a non-infinite number
Actual: <Infinity>
Which: is infinite''');
      });

      test('isCloseTo', () {
        check(() {
          check(1).isCloseTo(2, 0.5);
        }).throwsFailure().equals('''
Expected: a value within <0.5> of <2>
Actual: <1>
Which: differs by <1>''');
      });
    });

    group('string checks', () {
      test('isEmpty', () {
        check(() {
          check('foo').isEmpty();
        }).throwsFailure().equals('''
Expected: an empty string
Actual: 'foo'
Which: is not empty''');
      });

      test('contains', () {
        check(() {
          check('foo').contains('bar');
        }).throwsFailure().equals("""
Expected: a string that contains 'bar'
Actual: 'foo'
Which: does not contain 'bar'""");
      });

      test('isNotEmpty', () {
        check(() {
          check('').isNotEmpty();
        }).throwsFailure().equals('''
Expected: a non-empty string
Actual: ''
Which: is empty''');
      });

      test('startsWith', () {
        check(() {
          check('foo').startsWith('bar');
        }).throwsFailure().equals("""
Expected: a string starting with 'bar'
Actual: 'foo'
Which: does not start with 'bar'""");
      });

      test('endsWith', () {
        check(() {
          check('foo').endsWith('bar');
        }).throwsFailure().equals("""
Expected: a string ending with with 'bar'
Actual: 'foo'
Which: does not end with 'bar'""");
      });

      test('matchesPattern', () {
        check(() {
          check('foo').matchesPattern('bar');
        }).throwsFailure().equals("""
Expected: a string matching 'bar'
Actual: 'foo'
Which: does not match 'bar'""");
      });

      test('equalsIgnoringCase', () {
        check(() {
          check('foo').equalsIgnoringCase('bar');
        }).throwsFailure().equals('''
Expected: a string equal to 'bar' ignoring case
Actual: 'foo'
Which: differs at offset 0:
  bar
  foo
  ^''');
      });
    });

    group('iterable checks', () {
      test('isEmpty', () {
        check(() {
          check([1]).isEmpty();
        }).throwsFailure().equals('''
Expected: an empty iterable
Actual: [1]
Which: is not empty''');
      });

      test('isNotEmpty', () {
        check(() {
          check(<int>[]).isNotEmpty();
        }).throwsFailure().equals('''
Expected: a non-empty iterable
Actual: []
Which: is empty''');
      });

      test('contains', () {
        check(() {
          check([2]).contains(1);
        }).throwsFailure().equals('''
Expected: a list containing <1>
Actual: [2]
Which: does not contain <1>''');
      });

      test('contains (empty)', () {
        check(() {
          check(<int>[]).contains(1);
        }).throwsFailure().equals('''
Expected: a list containing <1>
Actual: an empty iterable''');
      });

      test('first collapses', () {
        check(() {
          check([1]).first.equals(2);
        }).throwsFailure().equals('''
Expected: a List<int> that has first element: <2>
Actual: a List<int> that has first element: <1>
Which: is not equal''');
      });

      test('last collapses', () {
        check(() {
          check([1]).last.equals(2);
        }).throwsFailure().equals('''
Expected: a List<int> that has last element: <2>
Actual: a List<int> that has last element: <1>
Which: is not equal''');
      });

      test('single collapses', () {
        check(() {
          check([1]).single.equals(2);
        }).throwsFailure().equals('''
Expected: a List<int> that has single element: <2>
Actual: a List<int> that has single element: <1>
Which: is not equal''');
      });
    });

    group('map checks', () {
      test('operator [] collapses', () {
        check(() {
          check({'a': 1})['a'].equals(2);
        }).throwsFailure().equals('''
Expected: a Map<String, int> that has entry <'a': <2>>
Actual: a Map<String, int> that has entry <'a': <1>>
Which: is not equal''');
      });

      test('operator [] fallback if key is large', () {
        final largeKey = Iterable.generate(30, (i) => i).toList();
        check(() {
          check({largeKey: 1})[largeKey].equals(2);
        }).throwsFailure().startsWith('''
Expected: a Map<List<int>, int> that:
  contains a value for [0,
''');
      });

      test('nested fallback collapses leaf', () {
        final multilineKey = 'foo\nbar';
        final foo = Foo('foo');
        check(() {
          check({multilineKey: foo})[multilineKey].someField.equals('bar');
        }).throwsFailure().equals('''
Expected: a Map<String, Foo> that:
  contains a value for 'foo
  bar' that:
    has someField: 'bar'
Actual: a Map<String, Foo> that:
  contains a value for 'foo
  bar' that:
    has someField: 'foo'
    Which: differs at offset 0:
      bar
      foo
      ^''');
      });

      test('isEmpty', () {
        check(() {
          check({'a': 1}).isEmpty();
        }).throwsFailure().equals('''
Expected: an empty map
Actual: {'a': 1}
Which: is not empty''');
      });

      test('isNotEmpty', () {
        check(() {
          check(<String, int>{}).isNotEmpty();
        }).throwsFailure().equals('''
Expected: a non-empty map
Actual: {}
Which: is not empty''');
      });

      test('containsKey', () {
        check(() {
          check({'a': 1}).containsKey('b');
        }).throwsFailure().equals("""
Expected: a map with key 'b'
Actual: {'a': 1}
Which: does not contain key 'b'""");
      });

      test('containsValue', () {
        check(() {
          check({'a': 1}).containsValue(2);
        }).throwsFailure().equals('''
Expected: a map with value <2>
Actual: {'a': 1}
Which: does not contain value <2>''');
      });
    });

    group('function checks', () {
      test('returnsNormally collapses', () {
        check(() {
          check(() => 1).returnsNormally().equals(2);
        }).throwsFailure().equals('''
Expected: a () => int that returns <2>
Actual: a () => int that returns <1>
Which: is not equal''');
      });

      test('throws collapses', () {
        check(() {
          void f() {
            throw 1;
          }

          check(f).throws<int>().equals(2);
        }).throwsFailure().equals('''
Expected: a () => void that throws <2>
Actual: a () => void that throws <1>
Which: is not equal''');
      });
    });

    group('async checks', () {
      test('emits collapses', () async {
        final stream = Stream.value(1);
        final checkStream = check(stream).withQueue.emits((it) => it.equals(2));
        await check(checkStream).throws<TestFailure>(
          (it) => it.has((f) => f.message, 'message').isNotNull().equals('''
Expected: a Stream<int> that:
  emits <2>
Actual: a Stream<int> that:
  emits <1>
  Which: is not equal'''),
        );
      });
    });
  });
}

class Foo {
  String field;
  Foo(this.field);
}

extension on Subject<Foo> {
  Subject<String> get someField => has((f) => f.field, 'someField');
}

extension on Subject<void Function()> {
  Subject<String> throwsFailure() =>
      throws<TestFailure>().has((f) => f.message, 'message').isNotNull();
}
