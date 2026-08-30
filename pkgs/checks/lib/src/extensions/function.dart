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
  Subject<E> throws<E>() {
    return context.nest<E>(() => ['throws an error of type $E'], (actual) {
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
    });
  }

  /// Expects that the function returns without throwing.
  ///
  /// If the function runs without exception, return a [Subject] to check
  /// further expecations on the returned value.
  ///
  /// If the function throws synchronously, this expectation will fail.
  Subject<T> returnsNormally() {
    return context.nest<T>(() => ['returns a value'], (actual) {
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
    });
  }

  /// Expects that the function prints text when called.
  ///
  /// Intercepts calls to [print] while the function is executed and returns
  /// a [Subject] to check expectations on the captured printed output.
  ///
  /// If the function throws synchronously, this expectation will fail.
  ///
  /// If this function is async and returns a [Future], this expectation will
  /// fail. Use [printsAsync] instead.
  Subject<String> prints() {
    return context.nest<String>(() => ['prints'], (actual) {
      final buffer = StringBuffer();
      try {
        final result = runZoned(
          actual,
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) {
              buffer.writeln(line);
            },
          ),
        );
        if (result is Future) {
          return Extracted.rejection(
            actual: ['a function that returned a Future'],
            which: [
              'returned a Future; use printsAsync to test asynchronous functions',
            ],
          );
        }
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
    });
  }

  /// Expects that the function prints text when called and completed.
  ///
  /// Intercepts calls to [print] while the function is executed and waits
  /// for the returned [Future] to complete before checking expectations
  /// on the captured printed output.
  ///
  /// If the function throws synchronously or returns a [Future] that completes
  /// with an error, this expectation will fail.
  @meta.awaitNotRequired
  Future<void> printsAsync([AsyncCondition<String>? printCondition]) {
    return context.nestAsync<String>(() => ['prints'], (actual) async {
      final buffer = StringBuffer();
      try {
        final result = runZoned(
          actual,
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) {
              buffer.writeln(line);
            },
          ),
        );
        if (result is Future) {
          await result;
        }
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
    }, printCondition);
  }
}
