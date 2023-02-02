import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:test_api/hooks.dart' show TestFailure;

void main() {
  group('failures', () {
    test('includes expected, actual, and which', () {
      checkThat(() {
        checkThat(1).isGreaterThan(2);
      }).throwsFailure(it()..equals('''
Expected: a int that:
  is greater than <2>
Actual: <1>
Which: is not greater than <2>'''));
    });

    test('includes matching portions of actual', () {
      checkThat(() {
        checkThat([]).hasLengthWhich(it()..equals(1));
      }).throwsFailure(it()..equals('''
Expected: a List<dynamic> that:
  has length that:
    equals <1>
Actual: a List<dynamic> that:
  has length that:
  Actual: <0>
  Which: are not equal'''));
    });

    test('include a reason when provided', () {
      checkThat(() {
        checkThat(because: 'Some reason', 1).isGreaterThan(2);
      }).throwsFailure(it()..endsWith('Reason: Some reason'));
    });

    test('retain type label following isNotNull', () {
      checkThat(() {
        checkThat<int?>(1).isNotNull(it()..isGreaterThan(2));
      }).throwsFailure(it()..startsWith('Expected: a int? that:\n'));
    });

    test('retain reason following isNotNull', () {
      checkThat(() {
        checkThat<int?>(because: 'Some reason', 1)
            .isNotNull(it()..isGreaterThan(2));
      }).throwsFailure(it()..endsWith('Reason: Some reason'));
    });
  });
}

extension on Subject<void Function()> {
  void throwsFailure(Condition<String> messageCondition) => throws<TestFailure>(
      it()
        ..has((f) => f.message, 'message',
            it<String?>()..isNotNull(messageCondition)));
}
