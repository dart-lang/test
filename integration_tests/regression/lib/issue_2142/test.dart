@Skip('https://github.com/dart-lang/test/issues/2142')
library;

import 'package:test/test.dart';
import 'import.dart';

void main() {
  test('aThing is a Thing', () {
    expect(newThing(), isA<Thing>());
  });
}

class Thing {}
