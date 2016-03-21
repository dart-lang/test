// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:test/src/util/io.dart';

import '../../io.dart';

void main() {
  useSandbox();

  test("ignores an empty file", () {
    d.file("dart_test.yaml", "").create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  test("pauses the test runner after a suite loads with pause_after_load: true",
      () {
    d.file("dart_test.yaml", JSON.encode({
      "pause_after_load": true
    })).create();

    d.file("test.dart", """
import 'package:test/test.dart';

void main() {
  print('loaded test!');

  test("success", () {});
}
""").create();

    var test = runTest(["-p", "content-shell", "test.dart"]);
    test.stdout.expect(consumeThrough("loaded test!"));
    test.stdout.expect(inOrder([
      "",
      startsWith("Observatory URL: "),
      startsWith("Remote debugger URL: "),
      "The test runner is paused. Open the remote debugger or the Observatory "
          "and set breakpoints. Once",
      "you're finished, return to this terminal and press Enter."
    ]));

    schedule(() async {
      var nextLineFired = false;
      test.stdout.next().then(expectAsync((line) {
        expect(line, contains("+0: success"));
        nextLineFired = true;
      }));

      // Wait a little bit to be sure that the tests don't start running without
      // our input.
      await new Future.delayed(new Duration(seconds: 2));
      expect(nextLineFired, isFalse);
    });

    test.writeLine('');
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  }, tags: 'content-shell');

  test("includes the full stack with verbose_trace: true", () {
    d.file("dart_test.yaml", JSON.encode({
      "verbose_trace": true
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("failure", () => throw "oh no");
      }
    """).create();

    var test = runTest(["test.dart"], reporter: "compact");
    test.stdout.expect(consumeThrough(contains("dart:isolate-patch")));
    test.shouldExit(1);
  });

  test("doesn't dartify stack traces for JS-compiled tests with js_trace: true",
      () {
    d.file("dart_test.yaml", JSON.encode({
      "js_trace": true
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("failure", () => throw "oh no");
      }
    """).create();

    var test = runTest(["-p", "chrome", "--verbose-trace", "test.dart"]);
    test.stdout.fork().expect(never(endsWith(" main.<fn>")));
    test.stdout.fork().expect(never(contains("package:test")));
    test.stdout.fork().expect(never(contains("dart:async/zone.dart")));
    test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
    test.shouldExit(1);
  }, tags: 'chrome');

  test("skips tests with skip: true", () {
    d.file("dart_test.yaml", JSON.encode({
      "skip": true
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("test", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains('All tests skipped.')));
    test.shouldExit(0);
  });

  test("skips tests with skip: reason", () {
    d.file("dart_test.yaml", JSON.encode({
      "skip": "Tests are boring."
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("test", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains('Tests are boring.')));
    test.stdout.expect(consumeThrough(contains('All tests skipped.')));
    test.shouldExit(0);
  });

  group("test_on", () {
    test("runs tests on a platform matching platform", () {
      d.file("dart_test.yaml", JSON.encode({
        "test_on": "vm"
      })).create();

      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains('All tests passed!')));
      test.shouldExit(0);
    });

    test("warns about the VM when no OSes are supported", () {
      d.file("dart_test.yaml", JSON.encode({
        "test_on": "chrome"
      })).create();

      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stderr.expect(
          "Warning: this package doesn't support running tests on the Dart "
            "VM.");
      test.stdout.expect(consumeThrough(contains('No tests ran.')));
      test.shouldExit(0);
    });

    test("warns about the OS when some OSes are supported", () {
      d.file("dart_test.yaml", JSON.encode({
        "test_on": otherOS
      })).create();

      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stderr.expect(
          "Warning: this package doesn't support running tests on "
            "${currentOS.name}.");
      test.stdout.expect(consumeThrough(contains('No tests ran.')));
      test.shouldExit(0);
    });

    test("warns about browsers in general when no browsers are supported", () {
      d.file("dart_test.yaml", JSON.encode({
        "test_on": "vm"
      })).create();

      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      """).create();

      var test = runTest(["-p", "chrome", "test.dart"]);
      test.stderr.expect(
          "Warning: this package doesn't support running tests on browsers.");
      test.stdout.expect(consumeThrough(contains('No tests ran.')));
      test.shouldExit(0);
    });

    test("warns about specific browsers when specific browsers are "
        "supported", () {
      d.file("dart_test.yaml", JSON.encode({
        "test_on": "safari"
      })).create();

      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      """).create();

      var test = runTest(["-p", "chrome,firefox,phantomjs", "test.dart"]);
      test.stderr.expect(
          "Warning: this package doesn't support running tests on Chrome, "
            "Firefox, or PhantomJS.");
      test.stdout.expect(consumeThrough(contains('No tests ran.')));
      test.shouldExit(0);
    });
  });

  test("uses the specified reporter", () {
    d.file("dart_test.yaml", JSON.encode({
      "reporter": "json"
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains('"testStart"')));
    test.shouldExit(0);
  });

  test("uses the specified pub serve port", () {
    d.file("pubspec.yaml", """
name: myapp
dependencies:
  barback: any
  test: {path: ${p.current}}
transformers:
- myapp:
    \$include: test/**_test.dart
- test/pub_serve:
    \$include: test/**_test.dart
""").create();

    d.dir("lib", [
      d.file("myapp.dart", """
        import 'package:barback/barback.dart';

        class MyTransformer extends Transformer {
          final allowedExtensions = '.dart';

          MyTransformer.asPlugin();

          Future apply(Transform transform) async {
            var contents = await transform.primaryInput.readAsString();
            transform.addOutput(new Asset.fromString(
                transform.primaryInput.id,
                contents.replaceAll("isFalse", "isTrue")));
          }
        }
      """)
    ]).create();

    runPub(['get']).shouldExit(0);

    d.dir("test", [
      d.file("my_test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("success", () => expect(true, isFalse));
        }
      """)
    ]).create();

    var pub = runPubServe();

    d.async(pubServePort.then((port) {
      return d.file("dart_test.yaml", JSON.encode({
        "pub_serve": port
      }));
    })).create();

    var test = runTest([]);
    test.stdout.expect(consumeThrough(contains('+1: All tests passed!')));
    test.shouldExit(0);
    pub.kill();
  });

  test("uses the specified concurrency", () {
    d.file("dart_test.yaml", JSON.encode({
      "concurrency": 2
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """).create();

    // We can't reliably test cthe concurrency, but this at least ensures that
    // it doesn't fail to parse.
    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  test("uses the specified timeout", () {
    d.file("dart_test.yaml", JSON.encode({
      "timeout": "0s"
    })).create();

    d.file("test.dart", """
      import 'dart:async';

      import 'package:test/test.dart';

      void main() {
        test("success", () => new Future.delayed(Duration.ZERO));
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(containsInOrder([
      "Test timed out after 0 seconds.",
      "-1: Some tests failed."
    ]));
    test.shouldExit(1);
  });

  test("runs on the specified platforms", () {
    d.file("dart_test.yaml", JSON.encode({
      "platforms": ["vm", "content-shell"]
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(containsInOrder([
      "[VM] success",
      "[Dartium Content Shell] success"
    ]));
    test.shouldExit(0);
  }, tags: "content-shell");

  test("command line args take precedence", () {
    d.file("dart_test.yaml", JSON.encode({
      "timeout": "0s"
    })).create();

    d.file("test.dart", """
      import 'dart:async';

      import 'package:test/test.dart';

      void main() {
        test("success", () => new Future.delayed(Duration.ZERO));
      }
    """).create();

    var test = runTest(["--timeout=none", "test.dart"]);
    test.stdout.expect(consumeThrough(contains("All tests passed!")));
    test.shouldExit(0);
  });

  test("uses the specified regexp names", () {
    d.file("dart_test.yaml", JSON.encode({
      "names": ["z[ia]p", "a"]
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("zip", () {});
        test("zap", () {});
        test("zop", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(containsInOrder([
      "+0: zap",
      "+1: All tests passed!"
    ]));
    test.shouldExit(0);
  });

  test("uses the specified plain names", () {
    d.file("dart_test.yaml", JSON.encode({
      "names": ["z", "a"]
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("zip", () {});
        test("zap", () {});
        test("zop", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(containsInOrder([
      "+0: zap",
      "+1: All tests passed!"
    ]));
    test.shouldExit(0);
  });

  test("uses the specified paths", () {
    d.file("dart_test.yaml", JSON.encode({
      "paths": ["zip", "zap"]
    })).create();

    d.dir("zip", [
      d.file("zip_test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("success", () {});
        }
      """)
    ]).create();

    d.dir("zap", [
      d.file("zip_test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("success", () {});
        }
      """)
    ]).create();

    d.dir("zop", [
      d.file("zip_test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("failure", () => throw "oh no");
        }
      """)
    ]).create();

    var test = runTest([]);
    test.stdout.expect(consumeThrough(contains('All tests passed!')));
    test.shouldExit(0);
  });

  test("uses the specified filename", () {
    d.file("dart_test.yaml", JSON.encode({
      "filename": "test_*.dart"
    })).create();

    d.dir("test", [
      d.file("test_foo.dart", """
        import 'package:test/test.dart';

        void main() {
          test("success", () {});
        }
      """),

      d.file("foo_test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("failure", () => throw "oh no");
        }
      """),

      d.file("test_foo.bart", """
        import 'package:test/test.dart';

        void main() {
          test("failure", () => throw "oh no");
        }
      """)
    ]).create();

    var test = runTest([]);
    test.stdout.expect(consumeThrough(contains('All tests passed!')));
    test.shouldExit(0);
  });
}
