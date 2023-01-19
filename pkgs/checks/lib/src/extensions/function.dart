// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/context.dart';

extension ThrowsCheck<T> on Check<T Function()> {
  /// Expects that a function throws synchronously when it is called.
  ///
  /// If the function synchronously throws a value of type [E], return a
  /// [Check<E>] to check further expectations on the error.
  ///
  /// If the function does not throw synchronously, or if it throws an error
  /// that is not of type [E], this expectation will fail.
  ///
  /// If this function is async and returns a [Future], this expectation will
  /// fail. Instead invoke the function and check the expectation on the
  /// returned [Future].
  Check<E> throws<E>() {
    return context.nest<E>('throws an error of type $E', (actual) {
      try {
        final result = actual();
        return Extracted.rejection(
          actual: prefixFirst('a function that returned ', literal(result)),
          which: ['did not throw'],
        );
      } catch (e) {
        if (e is E) return Extracted.value(e as E);
        return Extracted.rejection(
            actual: prefixFirst('a function that threw error ', literal(e)),
            which: ['did not throw an $E']);
      }
    });
  }

  /// Expects that the function returns without throwing.
  ///
  /// If the function runs without exception, return a [Check<T>] to check
  /// further expecations on the returned value.
  ///
  /// If the function throws synchronously, this expectation will fail.
  Check<T> returnsNormally() {
    return context.nest<T>('returns a value', (actual) {
      try {
        return Extracted.value(actual());
      } catch (e, st) {
        return Extracted.rejection(actual: [
          'a function that throws'
        ], which: [
          ...prefixFirst('threw ', literal(e)),
          ...st.toString().split('\n')
        ]);
      }
    });
  }
}
