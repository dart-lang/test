import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:test_api/hooks.dart' show TestFailure;

void main() {
  group('failures', () {
    test('includes expected, actual, and which', () {
      check(() {
        check(1).isGreaterThan(2);
      }).throwsFailure().equals('''
Expected: a int that:
  is greater than <2>
Actual: <1>
Which: is not greater than <2>''');
    });

    test('includes matching portions of actual', () {
      check(() {
        check([]).length.equals(1);
      }).throwsFailure().equals('''
Expected: a List<dynamic> that:
  has length that:
    equals <1>
Actual: a List<dynamic> that:
  has length that:
  Actual: <0>
  Which: are not equal''');
    });

    test('include a reason when provided', () {
      check(() {
        check(because: 'Some reason', 1).isGreaterThan(2);
      }).throwsFailure().endsWith('Reason: Some reason');
    });

    test('retain type label following isNotNull', () {
      check(() {
        check<int?>(1).isNotNull().isGreaterThan(2);
      }).throwsFailure().startsWith('Expected: a int? that:\n');
    });

    test('retain reason following isNotNull', () {
      check(() {
        check<int?>(because: 'Some reason', 1).isNotNull().isGreaterThan(2);
      }).throwsFailure().endsWith('Reason: Some reason');
    });
  });
}

extension on Subject<void Function()> {
  Subject<String> throwsFailure() =>
      throws<TestFailure>().has((f) => f.message, 'message').isNotNull();
}
