// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import '../io.dart';

void main() {
  useSandbox();

  test("reports when no tests are run", () {
    d.file("test.dart", "void main() {}").create();

    var test = runTest(["test.dart"], reporter: "xunit");
    test.stdout.expect(consumeThrough(contains("No tests ran.")));
    test.shouldExit(0);
  });

  test("runs several successful tests and reports when each completes", () {
    _expectReport(
        """
        test('success 1', () {});
        test('success 2', () {});
        test('success 3', () {});
        """,
        """
        <?xml version="1.0" encoding="UTF-8" ?>
        <testsuite name="All tests" tests="3" errors="0" failures="0" skipped="0">
          <testcase classname="test.dart" name="success 1" time="0"> </testcase>
          <testcase classname="test.dart" name="success 2" time="0"> </testcase>
          <testcase classname="test.dart" name="success 3" time="0"> </testcase>
        </testsuite>""");
  });

  test("runs several failing tests and reports when each fails", () {
    _expectReport(
        """
        test('failure 1', () => throw new TestFailure('oh no'));
        test('failure 2', () => throw new TestFailure('oh no'));
        test('failure 3', () => throw new TestFailure('oh no'));""",
        """
        <?xml version="1.0" encoding="UTF-8" ?>
        <testsuite name="All tests" tests="3" errors="0" failures="3" skipped="0">
          <testcase classname="test.dart" name="failure 1">
            <failure message="oh no">
              test.dart 6:33  main.&lt;fn&gt;
            </failure>
          </testcase>
          <testcase classname="test.dart" name="failure 2">
            <failure message="oh no">
              test.dart 7:33  main.&lt;fn&gt;
            </failure>
          </testcase>
          <testcase classname="test.dart" name="failure 3">
            <failure message="oh no">
              test.dart 8:33  main.&lt;fn&gt;
            </failure>
          </testcase>
        </testsuite>""");
  });

  test("runs failing tests along with successful tests", () {
    _expectReport(
        """
        test('failure 1', () => throw new TestFailure('oh no'));
        test('success 1', () {});
        test('failure 2', () => throw new TestFailure('oh no'));
        test('success 2', () {});""",
        """
        <?xml version="1.0" encoding="UTF-8" ?>
        <testsuite name="All tests" tests="4" errors="0" failures="2" skipped="0">
          <testcase classname="test.dart" name="failure 1">
            <failure message="oh no">
              test.dart 6:33  main.&lt;fn&gt;
            </failure>
          </testcase>
          <testcase classname="test.dart" name="success 1" time="0"> </testcase>
          <testcase classname="test.dart" name="failure 2">
            <failure message="oh no">
              test.dart 8:33  main.&lt;fn&gt;
            </failure>
          </testcase>
          <testcase classname="test.dart" name="success 2" time="0"> </testcase>
        </testsuite>""");
  });

  test("always prints the full test name", () {
    _expectReport(
        """
        test(
           'really gosh dang long test name. Even longer than that. No, yet '
               'longer. A little more... okay, that should do it.',
           () {});""",
        """
        <?xml version="1.0" encoding="UTF-8" ?>
        <testsuite name="All tests" tests="1" errors="0" failures="0" skipped="0">
          <testcase classname="test.dart" name="really gosh dang long test name. Even longer than that. No, yet longer. A little more... okay, that should do it." time="0"> </testcase>
        </testsuite>""");
  });

  test("gracefully handles multiple test failures in a row", () {
    _expectReport(
        """
        // This completer ensures that the test isolate isn't killed until all
        // errors have been thrown.
        var completer = new Completer();
        test('failures', () {
          new Future.microtask(() => throw 'first error');
          new Future.microtask(() => throw 'second error');
          new Future.microtask(() => throw 'third error');
          new Future.microtask(completer.complete);
        });
        test('wait', () => completer.future);""",
        """
        <?xml version="1.0" encoding="UTF-8" ?>
        <testsuite name="All tests" tests="2" errors="1" failures="0" skipped="0">
          <testcase classname="test.dart" name="failures">
            <error message="first error">
              test.dart 10:38  main.&lt;fn&gt;.&lt;fn&gt;
              ===== asynchronous gap ===========================
              dart:async       Future.Future.microtask
              test.dart 10:15  main.&lt;fn&gt;
            </error>
            <error message="second error">
              test.dart 11:38  main.&lt;fn&gt;.&lt;fn&gt;
              ===== asynchronous gap ===========================
              dart:async       Future.Future.microtask
              test.dart 11:15  main.&lt;fn&gt;
            </error>
            <error message="third error">
              test.dart 12:38  main.&lt;fn&gt;.&lt;fn&gt;
              ===== asynchronous gap ===========================
              dart:async       Future.Future.microtask
              test.dart 12:15  main.&lt;fn&gt;
            </error>
          </testcase>
          <testcase classname="test.dart" name="wait" time="0"> </testcase>
        </testsuite>""");
  });

  test("update testSuite heading with correct number of tests", () {
    _expectReport(
        """
        group('outerGroup',(){
          group('innerGroup1',(){
            test('failure 1', () => throw new TestFailure('oh no'));
            test('success 1', () {});
          });
          group('innerGroup2',(){
            test('failure 2', () => throw new TestFailure('oh no'));
            test('success 2', () {});
          });
        });
        """,
        """
        <?xml version="1.0" encoding="UTF-8" ?>
        <testsuite name="All tests" tests="4" errors="0" failures="2" skipped="0">
          <testsuite name="outerGroup" tests="4" failures="2">
            <testsuite name="innerGroup1" tests="2" failures="1">
              <testcase classname="test.dart" name="failure 1">
                <failure message="oh no">
                  test.dart 8:37  main.&lt;fn&gt;.&lt;fn&gt;.&lt;fn&gt;
                </failure>
              </testcase>
              <testcase classname="test.dart" name="success 1" time="0"> </testcase>
            </testsuite>
            <testsuite name="innerGroup2" tests="2" failures="1">
              <testcase classname="test.dart" name="failure 2">
                <failure message="oh no">
                  test.dart 12:37  main.&lt;fn&gt;.&lt;fn&gt;.&lt;fn&gt;
                </failure>
              </testcase>
              <testcase classname="test.dart" name="success 2" time="0"> </testcase>
            </testsuite>
          </testsuite>
        </testsuite>""");
  });

  group("print:", () {
    test("doesn't do anything", () {
      _expectReport(
          """
          test('test', () {
            print("one");
            print("two");
            print("three");
            print("four");
          });""",
          """
          <?xml version="1.0" encoding="UTF-8" ?>
          <testsuite name="All tests" tests="1" errors="0" failures="0" skipped="0">
            <testcase classname="test.dart" name="test" time="0"> </testcase>
          </testsuite>""");
    });
  });

  group("skip:", () {
    test("displays skipped tests separately", () {
      _expectReport(
          """
          test('skip 1', () {}, skip: true);
          test('skip 2', () {}, skip: true);
          test('skip 3', () {}, skip: true);""",
          """
          <?xml version="1.0" encoding="UTF-8" ?>
          <testsuite name="All tests" tests="3" errors="0" failures="0" skipped="3">
            <testcase classname="test.dart" name="skip 1">
              <skipped/>
            </testcase>
            <testcase classname="test.dart" name="skip 2">
              <skipped/>
            </testcase>
            <testcase classname="test.dart" name="skip 3">
              <skipped/>
            </testcase>
          </testsuite>""");
    });

    test("displays a skipped group", () {
      _expectReport(
          """
          group('skip', () {
            test('test 1', () {});
            test('test 2', () {});
            test('test 3', () {});
          }, skip: true);""",
          """
          <?xml version="1.0" encoding="UTF-8" ?>
          <testsuite name="All tests" tests="1" errors="0" failures="0" skipped="1">
            <testsuite name="skip" tests="1" skipped="1">
              <testcase classname="test.dart" name="">
                <skipped/>
              </testcase>
            </testsuite>
          </testsuite>""");
    });

    test("runs skipped tests along with successful tests", () {
      _expectReport(
          """
          test('skip 1', () {}, skip: true);
          test('success 1', () {});
          test('skip 2', () {}, skip: true);
          test('success 2', () {});""",
          """
          <?xml version="1.0" encoding="UTF-8" ?>
          <testsuite name="All tests" tests="4" errors="0" failures="0" skipped="2">
            <testcase classname="test.dart" name="skip 1">
              <skipped/>
            </testcase>
            <testcase classname="test.dart" name="success 1" time="0"> </testcase>
            <testcase classname="test.dart" name="skip 2">
              <skipped/>
            </testcase>
            <testcase classname="test.dart" name="success 2" time="0"> </testcase>
          </testsuite>""");
    });

    test("runs skipped tests along with successful and failing tests", () {
      _expectReport(
          """
          test('failure 1', () => throw new TestFailure('oh no'));
          test('skip 1', () {}, skip: true);
          test('success 1', () {});
          test('failure 2', () => throw new TestFailure('oh no'));
          test('skip 2', () {}, skip: true);
          test('success 2', () {});""",
          """
          <?xml version="1.0" encoding="UTF-8" ?>
          <testsuite name="All tests" tests="6" errors="0" failures="2" skipped="2">
            <testcase classname="test.dart" name="failure 1">
              <failure message="oh no">
                test.dart 6:35  main.&lt;fn&gt;
              </failure>
            </testcase>
            <testcase classname="test.dart" name="skip 1">
              <skipped/>
            </testcase>
            <testcase classname="test.dart" name="success 1" time="0"> </testcase>
            <testcase classname="test.dart" name="failure 2">
              <failure message="oh no">
                test.dart 9:35  main.&lt;fn&gt;
              </failure>
            </testcase>
            <testcase classname="test.dart" name="skip 2">
              <skipped/>
            </testcase>
            <testcase classname="test.dart" name="success 2" time="0"> </testcase>
          </testsuite>""");
    });

    test("displays the skip reason if available", () {
      _expectReport(
          """
          test('skip 1', () {}, skip: 'some reason');
          test('skip 2', () {}, skip: 'or another');""",
          """
          <?xml version="1.0" encoding="UTF-8" ?>
          <testsuite name="All tests" tests="2" errors="0" failures="0" skipped="2">
            <testcase classname="test.dart" name="skip 1">
              <skipped message="some reason"/>
            </testcase>
            <testcase classname="test.dart" name="skip 2">
              <skipped message="or another"/>
            </testcase>
          </testsuite>""");
    });
  });
}

void _expectReport(String tests, String expected) {
  var dart = """
import 'dart:async';

import 'package:test/test.dart';

void main() {
$tests
}
""";

  d.file("test.dart", dart).create();

  var test = runTest(["test.dart"], reporter: "xunit");
  test.shouldExit();

  schedule(() async {
    var stdoutLines = await test.stdoutStream().toList();

    // Remove excess trailing whitespace and trim off timestamps.
    var actual = stdoutLines.map((String line) {
      RegExp regExp = new RegExp(r'time="(\d+)"');
      var matches = regExp.allMatches(line).toList();
      return line.replaceFirst(new RegExp(r'time=\"(\d+)"'), 'time="0"');
    }).join("\n");

    // Un-indent the expected string.
    var indentation = expected.indexOf(new RegExp("[^ ]"));
    expected = expected.split("\n").map((line) {
      if (line.isEmpty) return line;
      return line.substring(indentation);
    }).join("\n");

    expect(actual, equals(expected));
  });
}
