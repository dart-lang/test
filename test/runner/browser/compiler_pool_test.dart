// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/util/exit_codes.dart' as exit_codes;
import 'package:test/test.dart';

import '../../io.dart';

String _sandbox;

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('test_').path;
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  test("doesn't intermingle warnings", () {
    // These files need trailing newlines to work around issue 22667.
    var testPath1 = p.join(_sandbox, "test1.dart");
    new File(testPath1).writeAsStringSync("String main() => 12;\n");

    var testPath2 = p.join(_sandbox, "test2.dart");
    new File(testPath2).writeAsStringSync("int main() => 'foo';\n");

    var result = _runUnittest(["-p", "chrome", "test1.dart", "test2.dart"]);
    expect(result.stdout, equals("""
Compiling test1.dart...
test1.dart:1:18:
Warning: 'int' is not assignable to 'String'.
String main() => 12;
                 ^^
Compiling test2.dart...
test2.dart:1:15:
Warning: 'String' is not assignable to 'int'.
int main() => 'foo';
              ^^^^^
"""));
    expect(result.exitCode, equals(exit_codes.data));
  });

  test("uses colors if the test runner uses colors", () {
    var testPath = p.join(_sandbox, "test.dart");
    new File(testPath).writeAsStringSync("String main() => 12;\n");

    var result = _runUnittest(["--color", "-p", "chrome", "test.dart"]);
    expect(result.stdout, contains('\u001b[35m'));
    expect(result.exitCode, equals(exit_codes.data));
  });
}

ProcessResult _runUnittest(List<String> args) =>
    runUnittest(args, workingDirectory: _sandbox);
