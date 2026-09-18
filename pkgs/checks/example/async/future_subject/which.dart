import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('which', () async {
    // This check succeeds. Multiple expectations are applied to the value the
    // future completed to.
    await check(Future.value(5)).completes().which(
      .it()
        ..isGreaterThan(0)
        ..isLessThan(10),
    );

    // This check fails on the second expectation.
    await check(Future.value(50)).completes().which(
      .it()
        ..isGreaterThan(0)
        ..isLessThan(10),
    );
    // Expected: a Future<int> that:
    //   completes to a value that:
    //     is greater than <0>
    //     is less than <10>
    // Actual: a Future<int> that completes to <50>
    // Which: is not less than <10>
  });
}
