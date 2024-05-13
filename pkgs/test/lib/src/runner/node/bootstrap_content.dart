// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_core/src/util/prefix.dart'; // ignore: implementation_imports

/// Generates the test bootstrap content for a node platform test runner.
String generateNodeBootstrapContent({
  required Uri testUri,
  required String languageVersionComment,
}) {
  return '''
        $languageVersionComment
        import "package:test/src/bootstrap/node.dart";

        import "$testUri" as $testSuiteImportPrefix;

        void main() {
          internalBootstrapNodeTest(() => test.main);
        }
      ''';
}
