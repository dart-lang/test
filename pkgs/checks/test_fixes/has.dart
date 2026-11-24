import 'package:checks/checks.dart';

void main() {
  check('abc').has((v) => v.length, 'length').equals(3);
  check('abc').has<int>((v) => v.length, 'length').equals(3);
  check('abc')
    ..has((v) => v.length, 'length').equals(3)
    ..has((v) => v.isEmpty, 'isEmpty').isFalse;
  check(['abc']).any(.it()..has((v) => v.length, 'length').equals(3));
}

extension CustomChecks on Subject<String> {
  Subject<int> get customLength => has((v) => v.length, 'length');
}
