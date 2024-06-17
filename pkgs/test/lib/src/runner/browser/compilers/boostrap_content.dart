// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_core/src/util/prefix.dart'; // ignore: implementation_imports

/// Generates the test bootstrap content for a dart2wasm test runner.
String generateDart2WasmBootstrapContent({
  required Uri testUri,
  required String languageVersionComment,
}) {
  return '''
        $languageVersionComment
        import 'package:test/src/bootstrap/browser.dart';

        import '$testUri' as $testSuiteImportPrefix;

        void main() {
          internalBootstrapBrowserTest(() => test.main);
        }
      ''';
}

/// Generates the test bootstrap content for a dart2js test runner.
String generateDart2JsBootstrapContent({
  required Uri testUri,
  required String testDartPath,
  required String languageVersionComment,
}) {
  return '''
        $languageVersionComment
        import 'package:test/src/bootstrap/browser.dart';
        import 'package:test/src/runner/browser/dom.dart' as dom;

        import '$testUri' as $testSuiteImportPrefix;

        void main() {
          dom.window.console.log(r'Startup for test path $testDartPath');
          internalBootstrapBrowserTest(() => test.main);
        }
      ''';
}
