// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import '../../io.dart';

final _success = """
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
""";

final _failure = """
import 'package:test/test.dart';

void main() {
  test("failure", () => throw new TestFailure("oh no"));
}
""";

void main() {
  useSandbox();

  group("fails gracefully if", () {
    test("a test file fails to compile", () {
      d.file("test.dart", "invalid Dart file").create();
      var test = runTest(["-p", "chrome", "test.dart"]);

      test.stdout.expect(containsInOrder([
        "Expected a declaration, but got 'invalid'",
        '-1: compiling test.dart',
        'Failed to load "test.dart": dart2js failed.'
      ]));
      test.shouldExit(1);
    });

    test("a test file throws", () {
      d.file("test.dart", "void main() => throw 'oh no';").create();

      var test = runTest(["-p", "chrome", "test.dart"]);
      test.stdout.expect(containsInOrder([
        '-1: compiling test.dart',
        'Failed to load "test.dart": oh no'
      ]));
      test.shouldExit(1);
    });

    test("a test file doesn't have a main defined", () {
      d.file("test.dart", "void foo() {}").create();

      var test = runTest(["-p", "chrome", "test.dart"]);
      test.stdout.expect(containsInOrder([
        '-1: compiling test.dart',
        'Failed to load "test.dart": No top-level main() function defined.'
      ]));
      test.shouldExit(1);
    });

    test("a test file has a non-function main", () {
      d.file("test.dart", "int main;").create();

      var test = runTest(["-p", "chrome", "test.dart"]);
      test.stdout.expect(containsInOrder([
        '-1: compiling test.dart',
        'Failed to load "test.dart": Top-level main getter is not a function.'
      ]));
      test.shouldExit(1);
    });

    test("a test file has a main with arguments", () {
      d.file("test.dart", "void main(arg) {}").create();

      var test = runTest(["-p", "chrome", "test.dart"]);
      test.stdout.expect(containsInOrder([
        '-1: compiling test.dart',
        'Failed to load "test.dart": Top-level main() function takes arguments.'
      ]));
      test.shouldExit(1);
    });

    test("a custom HTML file has no script tag", () {
      d.file("test.dart", "void main() {}").create();

      d.file("test.html", """
<html>
<head>
  <link rel="x-dart-test" href="test.dart">
</head>
</html>
""").create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart": "test.html" must contain '
            '<script src="packages/test/dart.js"></script>.'
      ]));
      test.shouldExit(1);
    });

    test("a custom HTML file has no link", () {
      d.file("test.dart", "void main() {}").create();

      d.file("test.html", """
<html>
<head>
  <script src="packages/test/dart.js"></script>
</head>
</html>
""").create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart": Expected exactly 1 '
            '<link rel="x-dart-test"> in test.html, found 0.'
      ]));
      test.shouldExit(1);
    });

    test("a custom HTML file has too many links", () {
      d.file("test.dart", "void main() {}").create();

      d.file("test.html", """
<html>
<head>
  <link rel='x-dart-test' href='test.dart'>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
</html>
""").create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart": Expected exactly 1 '
            '<link rel="x-dart-test"> in test.html, found 2.'
      ]));
      test.shouldExit(1);
    });

    test("a custom HTML file has no href in the link", () {
      d.file("test.dart", "void main() {}").create();

      d.file("test.html", """
<html>
<head>
  <link rel='x-dart-test'>
  <script src="packages/test/dart.js"></script>
</head>
</html>
""").create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart": Expected <link rel="x-dart-test"> in '
            'test.html to have an "href" attribute.'
      ]));
      test.shouldExit(1);
    });

    test("a custom HTML file has an invalid test URL", () {
      d.file("test.dart", "void main() {}").create();

      d.file("test.html", """
<html>
<head>
  <link rel='x-dart-test' href='wrong.dart'>
  <script src="packages/test/dart.js"></script>
</head>
</html>
""").create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart": Failed to load script at '
      ]));
      test.shouldExit(1);
    });

    // TODO(nweiz): test what happens when a test file is unreadable once issue
    // 15078 is fixed.
  });

  group("runs successful tests", () {
    test("on a JS and non-JS browser", () {
      d.file("test.dart", _success).create();
      var test = runTest(["-p", "content-shell", "-p", "chrome", "test.dart"]);

      test.stdout.fork().expect(consumeThrough(contains("[Chrome] compiling")));
      test.stdout.expect(never(contains("[Dartium Content Shell] compiling")));
      test.shouldExit(0);
    });

    test("on a browser and the VM", () {
      d.file("test.dart", _success).create();
      var test = runTest(["-p", "content-shell", "-p", "vm", "test.dart"]);

      test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      test.shouldExit(0);
    });

    test("with setUpAll", () {
      d.file("test.dart", r"""
          import 'package:test/test.dart';

          void main() {
            setUpAll(() => print("in setUpAll"));

            test("test", () {});
          }
          """).create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough(contains('+0: (setUpAll)')));
      test.stdout.expect('in setUpAll');
      test.shouldExit(0);
    });

    test("with tearDownAll", () {
      d.file("test.dart", r"""
          import 'package:test/test.dart';

          void main() {
            tearDownAll(() => print("in tearDownAll"));

            test("test", () {});
          }
          """).create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough(contains('+1: (tearDownAll)')));
      test.stdout.expect('in tearDownAll');
      test.shouldExit(0);
    });

    // Regression test; this broke in 0.12.0-beta.9.
    test("on a file in a subdirectory", () {
      d.dir("dir", [d.file("test.dart", _success)]).create();

      var test = runTest(["-p", "chrome", "dir/test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    group("with a custom HTML file", () {
      setUp(() {
        d.file("test.dart", """
import 'dart:html';

import 'package:test/test.dart';

void main() {
  test("success", () {
    expect(document.query('#foo'), isNotNull);
  });
}
""").create();

        d.file("test.html", """
<html>
<head>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
<body>
  <div id="foo"></div>
</body>
</html>
""").create();
      });

      test("on content shell", () {
        var test = runTest(["-p", "content-shell", "test.dart"]);
        test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
        test.shouldExit(0);
      });

      test("on Chrome", () {
        var test = runTest(["-p", "chrome", "test.dart"]);
        test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
        test.shouldExit(0);
      });

      // Regression test for https://github.com/dart-lang/test/issues/82.
      test("ignores irrelevant link tags", () {
        d.file("test.html", """
<html>
<head>
  <link rel='x-dart-test-not'>
  <link rel='other' href='test.dart'>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
<body>
  <div id="foo"></div>
</body>
</html>
""").create();

        var test = runTest(["-p", "content-shell", "test.dart"]);
        test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
        test.shouldExit(0);
      });
    });
  });

  group("runs failing tests", () {
    test("that fail only on the browser", () {
      d.file("test.dart", """
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test("test", () {
    if (p.style == p.Style.url) throw new TestFailure("oh no");
  });
}
""").create();

      var test = runTest(["-p", "content-shell", "-p", "vm", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1 -1: Some tests failed.")));
      test.shouldExit(1);
    });

    test("that fail only on the VM", () {
      d.file("test.dart", """
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test("test", () {
    if (p.style != p.Style.url) throw new TestFailure("oh no");
  });
}
""").create();

      var test = runTest(["-p", "content-shell", "-p", "vm", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1 -1: Some tests failed.")));
      test.shouldExit(1);
    });

    group("with a custom HTML file", () {
      setUp(() {
        d.file("test.dart", """
import 'dart:html';

import 'package:test/test.dart';

void main() {
  test("failure", () {
    expect(document.query('#foo'), isNull);
  });
}
""").create();

        d.file("test.html", """
<html>
<head>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
<body>
  <div id="foo"></div>
</body>
</html>
""").create();
      });

      test("on content shell", () {
        var test = runTest(["-p", "content-shell", "test.dart"]);
        test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
        test.shouldExit(1);
      });

      test("on Chrome", () {
        var test = runTest(["-p", "chrome", "test.dart"]);
        test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
        test.shouldExit(1);
      });
    });
  });

  test("the compiler uses colors if the test runner uses colors", () {
    d.file("test.dart", "String main() => 12;\n").create();

    var test = runTest(["--color", "-p", "chrome", "test.dart"]);
    test.stdout.expect(consumeThrough(contains('\u001b[35m')));
    test.shouldExit(1);
  });

  test("forwards prints from the browser test", () {
    d.file("test.dart", """
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("test", () {
    print("Hello,");
    return new Future(() => print("world!"));
  });
}
""").create();

    var test = runTest(["-p", "content-shell", "test.dart"]);
    test.stdout.expect(inOrder([
      consumeThrough("Hello,"),
      "world!"
    ]));
    test.shouldExit(0);
  });

  test("dartifies stack traces for JS-compiled tests by default", () {
    d.file("test.dart", _failure).create();

    var test = runTest(["-p", "chrome", "--verbose-trace", "test.dart"]);
    test.stdout.expect(containsInOrder([
      " main.<fn>",
      "package:test",
      "dart:async/zone.dart"
    ]));
    test.shouldExit(1);
  });

  test("doesn't dartify stack traces for JS-compiled tests with --js-trace", () {
    d.file("test.dart", _failure).create();

    var test = runTest(
        ["-p", "chrome", "--verbose-trace", "--js-trace", "test.dart"]);
    test.stdout.fork().expect(never(endsWith(" main.<fn>")));
    test.stdout.fork().expect(never(contains("package:test")));
    test.stdout.fork().expect(never(contains("dart:async/zone.dart")));
    test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
    test.shouldExit(1);
  });

  test("respects top-level @Timeout declarations", () {
    d.file("test.dart", '''
@Timeout(const Duration(seconds: 0))

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("timeout", () {});
}
''').create();

    var test = runTest(["-p", "content-shell", "test.dart"]);
    test.stdout.expect(containsInOrder([
      "Test timed out after 0 seconds.",
      "-1: Some tests failed."
    ]));
    test.shouldExit(1);
  });

  group("with onPlatform", () {
    test("respects matching Skips", () {
      d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no', onPlatform: {"browser": new Skip()});
}
''').create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+0 ~1: All tests skipped.")));
      test.shouldExit(0);
    });

    test("ignores non-matching Skips", () {
      d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {"vm": new Skip()});
}
''').create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("respects matching Timeouts", () {
      d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no', onPlatform: {
    "browser": new Timeout(new Duration(seconds: 0))
  });
}
''').create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        "Test timed out after 0 seconds.",
        "-1: Some tests failed."
      ]));
      test.shouldExit(1);
    });

    test("ignores non-matching Timeouts", () {
      d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {
    "vm": new Timeout(new Duration(seconds: 0))
  });
}
''').create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("applies matching platforms in order", () {
      d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {
    "browser": new Skip("first"),
    "browser || windows": new Skip("second"),
    "browser || linux": new Skip("third"),
    "browser || mac-os": new Skip("fourth"),
    "browser || android": new Skip("fifth")
  });
}
''').create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.fork().expect(never(contains("Skip: first")));
      test.stdout.fork().expect(never(contains("Skip: second")));
      test.stdout.fork().expect(never(contains("Skip: third")));
      test.stdout.fork().expect(never(contains("Skip: fourth")));
      test.stdout.expect(consumeThrough(contains("Skip: fifth")));
      test.shouldExit(0);
    });
  });

  group("with an @OnPlatform annotation", () {
    test("respects matching Skips", () {
      d.file("test.dart", '''
@OnPlatform(const {"browser": const Skip()})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no');
}
''').create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("~1: All tests skipped.")));
      test.shouldExit(0);
    });

    test("ignores non-matching Skips", () {
      d.file("test.dart", '''
@OnPlatform(const {"vm": const Skip()})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''').create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("respects matching Timeouts", () {
      d.file("test.dart", '''
@OnPlatform(const {
  "browser": const Timeout(const Duration(seconds: 0))
})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no');
}
''').create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        "Test timed out after 0 seconds.",
        "-1: Some tests failed."
      ]));
      test.shouldExit(1);
    });

    test("ignores non-matching Timeouts", () {
      d.file("test.dart", '''
@OnPlatform(const {
  "vm": const Timeout(const Duration(seconds: 0))
})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''').create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });
  });
}
