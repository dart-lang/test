import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:test_api/hooks.dart' show TestFailure;

void main() {
  group('failures', () {
    test('start with a label based on the type', () {
      checkThat(() {
        checkThat(1) > 2;
      }).throwsFailure().startsWith('Expected: a int that:\n');
    });

    test('include a reason when provided', () {
      checkThat(() {
        checkThat(because: 'Some reason', 1) > 2;
      }).throwsFailure().endsWith('Reason: Some reason');
    });

    test('retain type label following isNotNull', () {
      checkThat(() {
        checkThat<int?>(1).isNotNull() > 2;
      }).throwsFailure().startsWith('Expected: a int? that:\n');
    });

    test('retain reason following isNotNull', () {
      checkThat(() {
        checkThat<int?>(because: 'Some reason', 1).isNotNull() > 2;
      }).throwsFailure().endsWith('Reason: Some reason');
    });
  });
}

extension on Check<void Function()> {
  Check<String> throwsFailure() =>
      throws<TestFailure>().has((f) => f.message, 'message').isNotNull();
}
