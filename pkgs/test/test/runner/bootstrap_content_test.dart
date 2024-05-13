// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:test_core/src/runner/vm/platform.dart'; // ignore: implementation_imports

void main() {
  group('VmPlatform.bootstrapIsolateTestContents', () {
    test('generates expected output', () {
      final bootstrapContent = bootstrapIsolateTestContents(
        Uri.parse('file:///absolute/path/to/test/my_test.dart'),
        '',
      );
      expect(
        bootstrapContent,
        '''
    
    import "dart:isolate";
    import "package:test_core/src/bootstrap/vm.dart";
    import 'file:///absolute/path/to/test/my_test.dart' as test;
    void main(_, SendPort sendPort) {
      internalBootstrapVmTest(() => test.main, sendPort);
    }
  ''',
      );
    });

    test('contains test URI import with "test" prefix', () {
      final bootstrapContent = bootstrapNativeTestContents(
        Uri.parse('file:///absolute/path/to/test/my_test.dart'),
        '',
      );
      expect(
        bootstrapContent,
        contains(
          "import 'file:///absolute/path/to/test/my_test.dart' as test;",
        ),
        reason:
            'The test bootstrap content must contain an import of the test URI '
            'with the prefix "test". Dart DevTools depends on logic that '
            'searches for a prefix named "test" to find the URI of the Dart '
            'library under test. The "test" prefix matches the prefix '
            'generated by Flutter tools.',
      );
    });
  });

  group('VmPlatform.bootstrapNativeTestContents', () {
    test('generates expected output', () {
      final bootstrapContent = bootstrapNativeTestContents(
        Uri.parse('file:///absolute/path/to/test/my_test.dart'),
        '',
      );
      expect(
        bootstrapContent,
        '''
    
    import "dart:isolate";
    import "package:test_core/src/bootstrap/vm.dart";
    import 'file:///absolute/path/to/test/my_test.dart' as test;
    void main(List<String> args) {
      internalBootstrapNativeTest(() => test.main, args);
    }
  ''',
      );
    });

    test('contains test URI import with "test" prefix', () {
      final bootstrapContent = bootstrapNativeTestContents(
        Uri.parse('file:///absolute/path/to/test/my_test.dart'),
        '',
      );
      expect(
        bootstrapContent,
        contains(
          "import 'file:///absolute/path/to/test/my_test.dart' as test;",
        ),
        reason:
            'The test bootstrap content must contain an import of the test URI '
            'with the prefix "test". Dart DevTools depends on logic that '
            'searches for a prefix named "test" to find the URI of the Dart '
            'library under test. The "test" prefix matches the prefix '
            'generated by Flutter tools.',
      );
    });
  });
}
