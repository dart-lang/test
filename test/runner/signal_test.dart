// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test/src/util/io.dart';

import '../io.dart';

String _sandbox;

String get _tempDir => p.join(_sandbox, "tmp");

final _lines = UTF8.decoder.fuse(const LineSplitter());

// This test is inherently prone to race conditions. If it fails, it will likely
// do so flakily, but if it succeeds, it will succeed consistently. The tests
// represent a best effort to kill the test runner at certain times during its
// execution.
void main() {
  setUp(() {
    _sandbox = createTempDir();
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  group("during loading,", () {
    test("cleans up if killed while loading a VM test", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
void main() {
  print("in test.dart");
  // Spin for a long time so the test is probably killed while still loading.
  for (var i = 0; i < 100000000; i++) {}
}
""");

      return _startTest(["test.dart"]).then((process) {
        return _lines.bind(process.stdout).first.then((line) {
          expect(line, equals("in test.dart"));
          process.kill();
          return process.exitCode;
        }).then((_) {
          expect(new Directory(_tempDir).listSync(), isEmpty);
        });
      });
    });

    test("cleans up if killed while loading a browser test", () {
      new File(p.join(_sandbox, "test.dart"))
          .writeAsStringSync("void main() {}");

      return _startTest(["-p", "chrome", "test.dart"]).then((process) {
        return _lines.bind(process.stdout).first.then((line) {
          expect(line, equals("Compiling test.dart..."));
          process.kill();
          return process.exitCode;
        }).then((_) {
          expect(new Directory(_tempDir).listSync(), isEmpty);
        });
      });
    });

    test("exits immediately if ^C is sent twice", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
void main() {
  print("in test.dart");
  while (true) {}
}
""");

      return _startTest(["test.dart"]).then((process) {
        return _lines.bind(process.stdout).first.then((line) {
          expect(line, equals("in test.dart"));
          process.kill();

          // TODO(nweiz): Sending two signals in close succession can cause the
          // second one to be ignored, so we wait a bit before the second
          // one. Remove this hack when issue 23047 is fixed.
          return new Future.delayed(new Duration(seconds: 1));
        }).then((_) {
          process.kill();
          return process.exitCode;
        }).then((_) {
          expect(new Directory(_tempDir).listSync(), isEmpty);
        });
      });
    });
  });

  group("during test running", () {
    test("waits for a VM test to finish running", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  tearDown(() => new File("output").writeAsStringSync("ran teardown"));

  test("test", () {
    print("running test");
    return new Future.delayed(new Duration(seconds: 1));
  });
}
""");

      return _startTest(["test.dart"]).then((process) {
        return _lines.bind(process.stdout).skip(2).first.then((line) {
          expect(line, equals("running test"));
          process.kill();
          return process.exitCode;
        }).then((_) {
          expect(new File(p.join(_sandbox, "output")).readAsStringSync(),
              equals("ran teardown"));
          expect(new Directory(_tempDir).listSync(), isEmpty);
        });
      });
    });

    test("kills a browser test immediately", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("test", () {
    print("running test");

    // Allow an event loop to pass so the preceding print can be handled.
    return new Future(() {
      // Loop forever so that if the test isn't stopped while running, it never
      // stops.
      while (true) {}
    });
  });
}
""");

      return _startTest(["-p", "content-shell", "test.dart"]).then((process) {
        return _lines.bind(process.stdout).skip(3).first.then((line) {
          expect(line, equals("running test"));
          process.kill();
          return process.exitCode;
        }).then((_) {
          expect(new Directory(_tempDir).listSync(), isEmpty);
        });
      });
    });

    test("kills a VM test immediately if ^C is sent twice", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'package:test/test.dart';

void main() {
  test("test", () {
    print("running test");
    while (true) {}
  });
}
""");

      return _startTest(["test.dart"]).then((process) {
        return _lines.bind(process.stdout).skip(2).first.then((line) {
          expect(line, equals("running test"));
          process.kill();

          // TODO(nweiz): Sending two signals in close succession can cause the
          // second one to be ignored, so we wait a bit before the second
          // one. Remove this hack when issue 23047 is fixed.
          return new Future.delayed(new Duration(seconds: 1));
        }).then((_) {
          process.kill();
          return process.exitCode;
        });
      });
    });

    test("causes expect() to always throw an error immediately", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  var expectThrewError = false;

  tearDown(() {
    new File("output").writeAsStringSync(expectThrewError.toString());
  });

  test("test", () {
    print("running test");

    return new Future.delayed(new Duration(seconds: 1)).then((_) {
      try {
        expect(true, isTrue);
      } catch (_) {
        expectThrewError = true;
      }
    });
  });
}
""");

      return _startTest(["test.dart"]).then((process) {
        return _lines.bind(process.stdout).skip(2).first.then((line) {
          expect(line, equals("running test"));
          process.kill();
          return process.exitCode;
        }).then((_) {
          expect(new File(p.join(_sandbox, "output")).readAsStringSync(),
              equals("true"));
          expect(new Directory(_tempDir).listSync(), isEmpty);
        });
      });
    });

    test("causes expectAsync() to always throw an error immediately", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  var expectAsyncThrewError = false;

  tearDown(() {
    new File("output").writeAsStringSync(expectAsyncThrewError.toString());
  });

  test("test", () {
    print("running test");

    return new Future.delayed(new Duration(seconds: 1)).then((_) {
      try {
        expectAsync(() {});
      } catch (_) {
        expectAsyncThrewError = true;
      }
    });
  });
}
""");

      return _startTest(["test.dart"]).then((process) {
        return _lines.bind(process.stdout).skip(2).first.then((line) {
          expect(line, equals("running test"));
          process.kill();
          return process.exitCode;
        }).then((_) {
          expect(new File(p.join(_sandbox, "output")).readAsStringSync(),
              equals("true"));
          expect(new Directory(_tempDir).listSync(), isEmpty);
        });
      });
    });
  });
}

Future<Process> _startTest(List<String> args) {
  new Directory(_tempDir).create();
  return startTest(args, workingDirectory: _sandbox,
      environment: {"_UNITTEST_TEMP_DIR": _tempDir});
}
