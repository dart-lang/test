@TestOn('browser')
library;

import 'package:test/test.dart';

void main() {
  test('delayed chrome test', () async {
    await Future<void>.delayed(const Duration(seconds: 25));
    expect(1, equals(1));
  });
}
