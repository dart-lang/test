import 'package:test/test.dart';

import '../lib/issue_2142/import.dart';

void main() {
  test('aThing is a Thing', () {
    expect(newThing(), isA<Thing>());
  });
}

class Thing {}
