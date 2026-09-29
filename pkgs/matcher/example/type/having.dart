import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('having', () {
    expect(
      RangeError.range(5, 1, 3),
      isA<RangeError>()
          .having((e) => e.start, 'start', 1)
          .having((e) => e.end, 'end', 3),
    );
  });

  test('having on a top level matcher', () {
    // Every `isX` matcher is a `TypeMatcher`, so `having` can be chained onto
    // one without constructing an instance first.
    expect(
      () => throw RangeError.range(5, 10, 20),
      throwsA(
        isRangeError
            .having((e) => e.start, 'start', greaterThanOrEqualTo(10))
            .having((e) => e.end, 'end', lessThanOrEqualTo(20)),
      ),
    );
  });

  test('having when a feature does not match', () {
    // This check fails on the second feature.
    expect(
      RangeError.range(5, 1, 3),
      isA<RangeError>()
          .having((e) => e.start, 'start', 1)
          .having((e) => e.end, 'end', 10),
    );
    // Expected: <Instance of 'RangeError'> with `start`: <1> and `end`: <10>
    //   Actual: RangeError:<RangeError: Invalid value: Not in inclusive range 1..3: 5>
    //    Which: has `end` with value <3>
  });

  test('having when the type does not match', () {
    // This check fails before any feature is read.
    expect(
      StateError('nope'),
      isA<RangeError>().having((e) => e.start, 'start', 1),
    );
    // Expected: <Instance of 'RangeError'> with `start`: <1>
    //   Actual: StateError:<Bad state: nope>
    //    Which: is not an instance of 'RangeError'
  });
}
