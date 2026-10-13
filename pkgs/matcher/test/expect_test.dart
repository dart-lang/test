// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'utils_new.dart';

void main() {
  group('returned Future from expectLater()', () {
    test('completes immediately for a sync matcher', () {
      expect(expectLater(true, isTrue), completes);
    });

    test('contains the expect failure', () {
      expect(
        expectLater(Future.value(true), completion(isFalse)),
        throwsA(isTestFailure(anything)),
      );
    });

    test('contains an async error', () {
      expect(
        expectLater(Future<Never>.error('oh no'), completion(isFalse)),
        throwsA('oh no'),
      );
    });
  });

  group('an async matcher that fails synchronously', () {
    test('throws synchronously', () {
      expect(
        () => expect(() {}, throwsA(anything)),
        throwsA(isTestFailure(anything)),
      );
    });
  });

  group('async matchers in synchronous operators', () {
    Matcher rejects(String operator) => throwsA(
      isTestFailure(
        contains('$operator cannot be used with asynchronous matchers'),
      ),
    );

    test('are rejected by isNot', () {
      expect(() => expect(Future.value(1), isNot(completes)), rejects('isNot'));
      expect(
        () => expect(Future.value(1), isNot(doesNotComplete)),
        rejects('isNot'),
      );
      expect(() => expect(Stream.value(1), isNot(emits(1))), rejects('isNot'));
    });

    test('are rejected by anyOf', () {
      expect(
        () => expect(Future.value(1), anyOf(completes, isNull)),
        rejects('anyOf'),
      );
      expect(
        () => expect(Future.value(1), anyOf(isNull, completion(1))),
        rejects('anyOf'),
      );
    });

    test('are rejected when nested under isNot', () {
      expect(
        () => expect(Future.value(1), isNot(isNot(completes))),
        rejects('isNot'),
      );
      expect(
        () => expect(Future.value(1), isNot(allOf(isNotNull, completes))),
        rejects('isNot'),
      );
      expect(
        () => expect(Future.value(1), isNot(anyOf(isNull, completes))),
        rejects('isNot'),
      );
    });

    test('throw ArgumentError from matches', () {
      expect(
        () => isNot(completes).matches(Future.value(1), {}),
        throwsArgumentError,
      );
      expect(
        () => anyOf(completes).matches(Future.value(1), {}),
        throwsArgumentError,
      );
    });

    test('do not start async work when rejected', () {
      var called = false;
      expect(
        () => expect(() {
          called = true;
        }, isNot(prints(anything))),
        rejects('isNot'),
      );
      expect(called, isFalse);
    });

    group('throwsA', () {
      test('is allowed with a synchronous callback', () {
        expect(() {}, isNot(throwsA(anything)));
        expect(() => throw StateError('x'), isNot(throwsArgumentError));
        expect(
          () => throw StateError('x'),
          anyOf(throwsArgumentError, throwsStateError),
        );
        expect(
          () => expect(() => throw ArgumentError(), isNot(throwsArgumentError)),
          throwsA(
            isTestFailure(
              allOf(
                startsWith('Expected: not throws <Instance of'),
                isNot(contains('cannot be used')),
              ),
            ),
          ),
        );
      });

      test('is rejected with a callback that returns a Future', () {
        expect(
          () => expect(() async {}, isNot(throwsA(anything))),
          rejects('isNot'),
        );
        expect(
          () => expect(
            () => Future<void>.error('x'),
            anyOf(throwsArgumentError, throwsStateError),
          ),
          rejects('anyOf'),
        );
      });

      test('is rejected with a Future', () {
        expect(
          () => expect(Future.value(1), isNot(throwsA(anything))),
          rejects('isNot'),
        );
      });
    });

    test('are allowed in allOf', () async {
      await expectLater(
        Future.value(1),
        allOf(isA<Future<int>>(), completion(1)),
      );
    });

    test('allow negating the inner matcher', () async {
      await expectLater(Future.value(1), completion(isNot(2)));
      await expectLater(Future.value(1), completion(anyOf(1, 2)));
      await expectLater(
        () => throw ArgumentError(),
        throwsA(anyOf(isStateError, isArgumentError)),
      );
    });

    test('allow expect calls in callbacks run by operators', () async {
      expect(
        Future.value(1),
        isNot(
          predicate((Future<int> f) {
            expect(f, completes);
            return false;
          }),
        ),
      );
    });
  });
}
