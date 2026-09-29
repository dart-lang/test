import 'package:matcher/expect.dart';
import 'package:test/scaffolding.dart';

class _HasParsedValue extends CustomMatcher {
  _HasParsedValue(Object? valueOrMatcher)
    : super(
        'String parsing to a value that is',
        'parsed value',
        valueOrMatcher,
      );

  @override
  Object? featureValueOf(dynamic actual) => int.parse(actual as String);
}

void main() {
  test('CustomMatcher', () {
    // This check succeeds.
    expect('42', _HasParsedValue(42));

    // This check fails, and the message describes the derived feature.
    expect('42', _HasParsedValue(lessThan(10)));
    // Expected: String parsing to a value that is a value less than <10>
    //   Actual: '42'
    //    Which: has parsed value with value <42> which is not a value less than <10>
  });
}
