import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('operator []', () {
    final scores = {'alice': 90, 'bob': 85};
    check(scores)['alice'].equals(90);
  });

  test('operator [] with a key that is missing', () {
    final scores = {'alice': 90, 'bob': 85};
    check(scores)['carol'].equals(70);
    // Expected: a Map<String, int> that:
    //   contains a value for 'carol'
    // Actual: {'alice': 90, 'bob': 85}
    // Which: does not contain the key 'carol'
  });

  test('operator [] with a value that does not match', () {
    final scores = {'alice': 90, 'bob': 85};
    check(scores)['bob'].equals(90);
    // Expected: a Map<String, int> that has entry <'bob': <90>>
    // Actual: a Map<String, int> that has entry <'bob': <85>>
    // Which: is not equal
  });
}
