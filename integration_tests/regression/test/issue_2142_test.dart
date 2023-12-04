@Skip('https://github.com/dart-lang/test/issues/2142')
library;

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/issue_2142/import.dart';

void main() {
  test('aThing is a Thing', () {
    expect(newThing(), isA<Thing>());
  });
}

class Thing {}
