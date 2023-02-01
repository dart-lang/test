import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:test_api/hooks.dart' show TestFailure;

void main() {
  group('failures', () {
    test('includes expected, actual, and which', () {
      (() {
        1.must.beGreaterThan(2);
      }).must.throwsFailure().equal('''
Expected: a int that:
  is greater than <2>
Actual: <1>
Which: is not greater than <2>''');
    });

    test('includes matching portions of actual', () {
      (() {
        [].must.haveLength.equal(1);
      }).must.throwsFailure().equal('''
Expected: a List<dynamic> that:
  has length that:
    equals <1>
Actual: a List<dynamic> that:
  has length that:
  Actual: <0>
  Which: are not equal''');
    });

    // test('include a reason when provided', () {
    //   (() {
    //     (because: 'Some reason', 1).should.isGreaterThan(2);
    //   }).should.throwsFailure().endsWith('Reason: Some reason');
    // });

    test('retain type label following isNotNull', () {
      (() {
        int? nullableIntNoPromotion() => 1;
        var actual = nullableIntNoPromotion();
        actual.must.beNonNull().beGreaterThan(2);
      }).must.throwsFailure().startWith('Expected: a int? that:\n');
    });

    // test('retain reason following isNotNull', () {
    //   (() {
    //     <int?>(because = 'Some reason', 1).should.isNotNull().isGreaterThan(2);
    //   }).should.throwsFailure().endsWith('Reason: Some reason');
    // });
  });
}

extension on Subject<void Function()> {
  Subject<String> throwsFailure() => throwException<TestFailure>()
      .have((f) => f.message, 'message')
      .beNonNull();
}
