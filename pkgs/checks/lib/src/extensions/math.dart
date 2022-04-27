import 'package:checks/context.dart';

extension NumChecks on Check<num> {
  void operator >(num other) {
    context.expect(() => ['is greater than ${literal(other)}'], (actual) {
      if (actual > other) return null;
      return Rejection(
          actual: literal(actual),
          which: ['Is not greater than ${literal(other)}']);
    });
  }

  void operator <(num other) {
    context.expect(() => ['is less than ${literal(other)}'], (actual) {
      if (actual < other) return null;
      return Rejection(
          actual: literal(actual),
          which: ['Is not less than ${literal(other)}']);
    });
  }
}
