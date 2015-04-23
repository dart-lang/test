// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/util/io.dart';
import 'package:test/test.dart';

import '../../io.dart';

String _sandbox;

void main() {
  setUp(() {
    _sandbox = createTempDir();
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  test("prints the platform name when running on multiple platforms", () {
    new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
""");

    var result = _runTest([
      "-r",
      "expanded",
      "-p",
      "content-shell",
      "-p",
      "vm",
      "-j",
      "1",
      "test.dart"
    ]);
    expect(result.stdout, contains("[VM]"));
    expect(result.stdout, contains("[Dartium Content Shell]"));
    expect(result.exitCode, equals(0));
  });
}

ProcessResult _runTest(List<String> args) =>
    runTest(args, workingDirectory: _sandbox);
