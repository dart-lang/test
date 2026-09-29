// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart' as meta;

import '../../context.dart';

extension FunctionChecks<T> on Subject<T Function()> {
  /// Expects that a function throws synchronously when it is called.
  ///
  /// If the function synchronously throws a value of type [E], return a
  /// [Subject] to check further expectations on the error.
  ///
  /// If the function does not throw synchronously, or if it throws an error
  /// that is not of type [E], this expectation will fail.
  ///
  /// If this function is async and returns a [Future], this expectation will
  /// fail. Instead invoke the function and check the expectation on the
  /// returned [Future].
  ///
  /// {@example /example/function/function/throws.dart}
  Subject<E> throws<E>([Condition<E>? that]) => context.nest<E>(
    () {
      var label = 'throws an error';
      if (const Object() is! E) {
        label = '$label of type $E';
      }
      return [label];
    },
    addPredicate: (predicateNoun) => 'throws $predicateNoun',
    (actual) {
      try {
        final result = actual();
        return Extracted.rejection(
          actual: prefixFirst('a function that returned ', literal(result)),
          which: ['did not throw'],
        );
      } catch (e, st) {
        if (e is E) return Extracted.value(e as E);
        return Extracted.rejection(
          actual: prefixFirst('a function that threw error ', literal(e)),
          which: [
            'threw an exception that is not a $E at:',
            ...indent(LineSplitter.split(st.toString())),
          ],
        );
      }
    },
    nestedCondition: that,
  );

  /// Expects that the function returns without throwing.
  ///
  /// If the function runs without exception, return a [Subject] to check
  /// further expecations on the returned value.
  ///
  /// If the function throws synchronously, this expectation will fail.
  ///
  /// {@example /example/function/function/returns_normally.dart}
  Subject<T> returnsNormally([Condition<T>? that]) => context.nest<T>(
    () => ['returns a value'],
    addPredicate: (predicateNoun) => 'returns $predicateNoun',
    (actual) {
      try {
        return Extracted.value(actual());
      } catch (e, st) {
        return Extracted.rejection(
          actual: ['a function that throws'],
          which: [
            ...prefixFirst('threw ', postfixLast(' at:', literal(e))),
            ...indent(LineSplitter.split(st.toString())),
          ],
        );
      }
    },
    nestedCondition: that,
  );
}

/// Expectation extensions which need to have lower precedence than
/// [AsyncFuntionChecks].
extension VoidFunctionChecks on Subject<void Function()> {
  /// Expects that the function prints text when called.
  ///
  /// Intercepts calls to [print] while the function is executed and returns
  /// a [Subject] to check expectations on the captured printed output.
  ///
  /// If the function throws synchronously, this expectation will fail.
  ///
  /// {@example /example/function/function/prints.dart}
  Subject<String> prints([Condition<String>? that]) {
    return context.nest<String>(
      () => ['prints'],
      addPredicate: (predicateNoun) => 'prints $predicateNoun',
      (actual) {
        final buffer = StringBuffer();
        final Object? result;
        try {
          result = runZoned(
            actual,
            zoneSpecification: ZoneSpecification(
              print: (_, _, _, line) {
                buffer.writeln(line);
              },
            ),
          );
        } catch (e, st) {
          return Extracted.rejection(
            actual: ['a function that throws'],
            which: [
              ...prefixFirst('threw ', postfixLast(' at:', literal(e))),
              ...indent(LineSplitter.split(st.toString())),
            ],
          );
        }
        assert(
          result is! Future,
          'Function returned a Future. Provide a `Future<void> Function()` to '
          'check asynchronous prints.',
        );
        return Extracted.value(buffer.toString());
      },
      nestedCondition: that,
    );
  }
}

extension AsyncFunctionChecks on Subject<Future<void> Function()> {
  /// Expects that the asynchronous function prints text when called and
  /// completed.
  ///
  /// Intercepts calls to [print] while the function is executed and waits
  /// for the returned [Future] to complete before checking expectations
  /// on the captured printed output.
  ///
  /// If the function throws synchronously or returns a [Future] that completes
  /// with an error, this expectation will fail.
  ///
  /// {@example /example/function/async_function/prints.dart}
  @meta.awaitNotRequired
  Future<Subject<String>> prints([Condition<String>? printCondition]) {
    return context.nestAsync<String>(
      () => ['prints'],
      addPredicate: (predicateNoun) => 'prints $predicateNoun',
      (actual) async {
        final buffer = StringBuffer();
        try {
          await runZoned(
            actual,
            zoneSpecification: ZoneSpecification(
              print: (_, _, _, line) {
                buffer.writeln(line);
              },
            ),
          );
          return Extracted.value(buffer.toString());
        } catch (e, st) {
          return Extracted.rejection(
            actual: ['a function that throws'],
            which: [
              ...prefixFirst('threw ', postfixLast(' at:', literal(e))),
              ...indent(LineSplitter.split(st.toString())),
            ],
          );
        }
      },
      printCondition,
    );
  }
}
