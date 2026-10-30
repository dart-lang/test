import 'dart:async';

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('failures', () {
    test('includes expected, actual, and which', () {
      check(() {
        check(1).isGreaterThan(2);
      }).throwsFailure().equals('''
Expected: a value > <2>
Actual: <1>
Which: is not greater than <2>''');
    });

    test('includes matching portions of actual', () {
      check(() {
        check(<dynamic>[]).length
          ..isLessThan(10)
          ..isGreaterThan(1);
      }).throwsFailure().equals('''
Expected: a List<dynamic> that:
  has length that:
    is less than <10>
    is greater than <1>
Actual: a List<dynamic> that has length: <0>
Which: is not greater than <1>''');
    });

    test('includes matching portions of actual when label is multiline', () {
      check(() {
        check({
            'foo\nbar': [10],
          })['foo\nbar'].first
          ..isGreaterThan(0)
          ..isLessThan(10);
      }).throwsFailure().equals('''
Expected: a Map<String, List<int>> that:
  contains a value for 'foo
  bar' that:
    has first element that:
      is greater than <0>
      is less than <10>
Actual: a Map<String, List<int>> that:
  contains a value for 'foo
  bar' that:
    has first element: <10>
    Which: is not less than <10>''');
    });

    test('include a reason when provided', () {
      check(() {
        check(because: 'Some reason', 1).isGreaterThan(2);
      }).throwsFailure().endsWith('Reason: Some reason');
    });

    test('retain type label following isNotNull', () {
      check(() {
        check<int?>(1).isNotNull()
          ..isGreaterThan(0)
          ..isLessThan(0);
      }).throwsFailure().equals('''
Expected: a int? that:
  is not null
  is greater than <0>
  is less than <0>
Actual: <1>
Which: is not less than <0>''');
    });

    test('retain reason following isNotNull', () {
      check(() {
        check<int?>(because: 'Some reason', 1).isNotNull().isGreaterThan(2);
      }).throwsFailure().endsWith('Reason: Some reason');
    });

    test('nested uncollapsed failure retains isNotNull in expected', () {
      check(() {
        check(<int?>[1]).first.isNotNull()
          ..isGreaterThan(0)
          ..isLessThan(0);
      }).throwsFailure().equals('''
Expected: a List<int?> that:
  has first element that:
    is not null
    is greater than <0>
    is less than <0>
Actual: a List<int?> that has first element: <1>
Which: is not less than <0>''');
    });

    test('handles objects with empty toString', () {
      check(() {
        check(EmptyToString()).equals(EmptyToString());
      }).throwsFailure().equals('''
Expected: <empty toString()>
Actual: <empty toString()>
Which: is not equal''');
    });
    test('succeeded child context followed by failing check on parent', () {
      check(() {
        check([1])
          ..has2('first', (l) => l.first).equals(1)
          ..equals([2]);
      }).throwsFailure().equals('''
Expected: a List<int> that:
  has first: <1>
  equals [2]
Actual: [1]
Which: is not equal''');
    });
    test('omits an expectation made before an earlier asynchronous '
        'expectation fails', () async {
      final subject = check(Future.value(1));
      final completion = subject.completes(.it()..equals(2));
      subject.has((f) => 0, 'zero').equals(0);
      await check(completion).throws<TestFailure>(
        .it()
          ..has((f) => f.message, 'message').isNotNull().equals('''
Expected: a Future<int> that completes to <2>
Actual: a Future<int> that completes to <1>
Which: is not equal'''),
      );
    });
    test('omits an asynchronous expectation which has not completed when '
        'a later expectation fails', () async {
      final completer = Completer<int>();
      check(() {
        check(completer.future)
          ..completes()
          ..has((f) => 0, 'zero').equals(1);
      }).throwsFailure().equals('''
Expected: a Future<int> that has zero: <1>
Actual: a Future<int> that has zero: <0>
Which: is not equal''');
      completer.complete(1);
    });
    test('omits an asynchronous expectation which has not finished when a '
        'later nested expectation fails', () async {
      final completer = Completer<Rejection?>();
      check(() {
        check(0)
          ..context.expectAsync(() => ['waits'], (_) => completer.future)
          ..has((v) => v, 'self').equals(1);
      }).throwsFailure().equals('''
Expected: a int that has self: <1>
Actual: a int that has self: <0>
Which: is not equal''');
      completer.complete(null);
    });
    test('omits expectations after an unawaited expectation which fails '
        'later', () async {
      Object? failure;
      final completer = Completer<int>();
      runZonedGuarded(
        () {
          check(completer.future)
            ..doesNotComplete
            ..has((f) => 0, 'zero').equals(0);
          completer.complete(1);
        },
        (e, _) {
          failure = e;
        },
      );
      await pumpEventQueue();
      check(failure)
          .isA<TestFailure>()
          .has((f) => f.message, 'message')
          .isNotNull()
          .equals('''
Expected: a Future<int> that:
  does not complete
Actual: a future that completed to <1>''');
    });
  });
}

extension on Subject<void Function()> {
  Subject<String> throwsFailure() =>
      throws<TestFailure>().has2('message', (f) => f.message).isNotNull();
}

class EmptyToString {
  @override
  String toString() => '';
}
