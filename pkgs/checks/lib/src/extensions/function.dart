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
    return context.nest<E>('Completes as an error of type $E', (actual) {
      try {
        final result = actual();
        return Extracted.rejection(
          actual: 'Returned ${literal(result)}',
          which: ['Did not throw'],
        );
      } catch (e) {
        if (e is E) return Extracted.value(e as E);
        return Extracted.rejection(
            actual: 'Completed to error ${literal(e)}',
            which: ['Is not an $E']);
      }
    });
  }
}
