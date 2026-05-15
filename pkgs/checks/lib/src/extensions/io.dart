// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../context.dart';

extension IoFunctionChecks<T> on Subject<T Function()> {
  /// Expects that a function calls [exit] synchronously when it is called.
  ///
  /// If the function synchronously calls [exit], return a [Subject] to check
  /// further expectations on the exit code.
  ///
  /// If the function does not call [exit] synchronously, or if it throws an
  /// error, this expectation will fail.
  Subject<int> exits() {
    return context.nest<int>(() => ['exits the process'], (actual) {
      try {
        final result = IOOverrides.runWithIOOverrides(
          actual,
          _ExitIOOverrides(),
        );
        return Extracted.rejection(
          actual: prefixFirst('a function that returned ', literal(result)),
          which: ['did not exit'],
        );
      } on _ExitException catch (e) {
        return Extracted.value(e.code);
      } catch (e) {
        return Extracted.rejection(
          actual: prefixFirst('a function that threw error ', literal(e)),
          which: ['did not exit'],
        );
      }
    });
  }
}

extension IoAsyncFunctionChecks<T> on Subject<Future<T> Function()> {
  /// Expects that the future returned by the function calls [exit]
  /// asynchronously.
  ///
  /// If the future calls [exit], check further expectations on the exit code
  /// with [exitCodeCondition].
  ///
  /// If the future completes normally or completes to an error, this
  /// expectation will fail.
  Future<void> exits([AsyncCondition<int>? exitCodeCondition]) async {
    await context.nestAsync<int>(() => ['exits the process'], (actual) async {
      try {
        final result = await IOOverrides.runWithIOOverrides(
          actual,
          _ExitIOOverrides(),
        );
        return Extracted.rejection(
          actual: prefixFirst('completed to ', literal(result)),
          which: ['did not exit'],
        );
      } on _ExitException catch (e) {
        return Extracted.value(e.code);
      } catch (e, st) {
        return Extracted.rejection(
          actual: prefixFirst('completed to error ', literal(e)),
          which: [
            'threw an exception at:',
            ...const LineSplitter().convert(st.toString()),
          ],
        );
      }
    }, exitCodeCondition);
  }
}

final class _ExitException implements Exception {
  final int code;
  _ExitException(this.code);
}

final class _ExitIOOverrides extends IOOverrides {
  @override
  Never exit(int code) {
    throw _ExitException(code);
  }
}
