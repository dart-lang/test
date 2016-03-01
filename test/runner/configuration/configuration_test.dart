// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'package:boolean_selector/boolean_selector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:test/src/backend/platform_selector.dart';
import 'package:test/src/backend/test_platform.dart';
import 'package:test/src/runner/configuration.dart';
import 'package:test/src/runner/configuration/values.dart';
import 'package:test/src/util/io.dart';

void main() {
  group("merge", () {
    group("for most fields", () {
      test("if neither is defined, preserves the default", () {
        var merged = new Configuration().merge(new Configuration());
        expect(merged.help, isFalse);
        expect(merged.version, isFalse);
        expect(merged.verboseTrace, isFalse);
        expect(merged.jsTrace, isFalse);
        expect(merged.skip, isFalse);
        expect(merged.skipReason, isNull);
        expect(merged.pauseAfterLoad, isFalse);
        expect(merged.color, equals(canUseSpecialChars));
        expect(merged.packageRoot, equals(p.join(p.current, 'packages')));
        expect(merged.reporter, equals(defaultReporter));
        expect(merged.pubServeUrl, isNull);
        expect(merged.pattern, isNull);
        expect(merged.platforms, equals([TestPlatform.vm]));
        expect(merged.paths, equals(["test"]));
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = new Configuration(
                help: true,
                version: true,
                verboseTrace: true,
                jsTrace: true,
                skip: true,
                skipReason: "boop",
                pauseAfterLoad: true,
                color: true,
                packageRoot: "root",
                reporter: "json",
                pubServePort: 1234,
                pattern: "foo",
                platforms: [TestPlatform.chrome],
                paths: ["bar"])
            .merge(new Configuration());

        expect(merged.help, isTrue);
        expect(merged.version, isTrue);
        expect(merged.verboseTrace, isTrue);
        expect(merged.jsTrace, isTrue);
        expect(merged.skip, isTrue);
        expect(merged.skipReason, equals("boop"));
        expect(merged.pauseAfterLoad, isTrue);
        expect(merged.color, isTrue);
        expect(merged.packageRoot, equals("root"));
        expect(merged.reporter, equals("json"));
        expect(merged.pubServeUrl.port, equals(1234));
        expect(merged.pattern, equals("foo"));
        expect(merged.platforms, equals([TestPlatform.chrome]));
        expect(merged.paths, equals(["bar"]));
      });

      test("if only the new configuration's is defined, uses it", () {
        var merged = new Configuration().merge(new Configuration(
            help: true,
            version: true,
            verboseTrace: true,
            jsTrace: true,
            skip: true,
            skipReason: "boop",
            pauseAfterLoad: true,
            color: true,
            packageRoot: "root",
            reporter: "json",
            pubServePort: 1234,
            pattern: "foo",
            platforms: [TestPlatform.chrome],
            paths: ["bar"]));

        expect(merged.help, isTrue);
        expect(merged.version, isTrue);
        expect(merged.verboseTrace, isTrue);
        expect(merged.jsTrace, isTrue);
        expect(merged.skip, isTrue);
        expect(merged.skipReason, equals("boop"));
        expect(merged.pauseAfterLoad, isTrue);
        expect(merged.color, isTrue);
        expect(merged.packageRoot, equals("root"));
        expect(merged.reporter, equals("json"));
        expect(merged.pubServeUrl.port, equals(1234));
        expect(merged.pattern, equals("foo"));
        expect(merged.platforms, equals([TestPlatform.chrome]));
        expect(merged.paths, equals(["bar"]));
      });

      test("if the two configurations conflict, uses the new configuration's "
          "values", () {
        var older = new Configuration(
            help: true,
            version: false,
            verboseTrace: true,
            jsTrace: false,
            skip: true,
            skipReason: "foo",
            pauseAfterLoad: true,
            color: false,
            packageRoot: "root",
            reporter: "json",
            pubServePort: 1234,
            pattern: "foo",
            platforms: [TestPlatform.chrome],
            paths: ["bar"]);
        var newer = new Configuration(
            help: false,
            version: true,
            verboseTrace: false,
            jsTrace: true,
            skip: true,
            skipReason: "bar",
            pauseAfterLoad: false,
            color: true,
            packageRoot: "boot",
            reporter: "compact",
            pubServePort: 5678,
            pattern: "gonk",
            platforms: [TestPlatform.dartium],
            paths: ["blech"]);
        var merged = older.merge(newer);

        expect(merged.help, isFalse);
        expect(merged.version, isTrue);
        expect(merged.verboseTrace, isFalse);
        expect(merged.jsTrace, isTrue);
        expect(merged.skipReason, equals("bar"));
        expect(merged.pauseAfterLoad, isFalse);
        expect(merged.color, isTrue);
        expect(merged.packageRoot, equals("boot"));
        expect(merged.reporter, equals("compact"));
        expect(merged.pubServeUrl.port, equals(5678));
        expect(merged.pattern, equals("gonk"));
        expect(merged.platforms, equals([TestPlatform.dartium]));
        expect(merged.paths, equals(["blech"]));
      });
    });

    group("for testOn", () {
      test("if neither is defined, preserves the default", () {
        var merged = new Configuration().merge(new Configuration());
        expect(merged.testOn, equals(PlatformSelector.all));
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = new Configuration(
                testOn: new PlatformSelector.parse("chrome"))
            .merge(new Configuration());
        expect(merged.testOn, equals(new PlatformSelector.parse("chrome")));
      });

      test("if only the new configuration's is defined, uses it", () {
        var merged = new Configuration()
            .merge(new Configuration(
                testOn: new PlatformSelector.parse("chrome")));
        expect(merged.testOn, equals(new PlatformSelector.parse("chrome")));
      });

      test("if both are defined, intersects them", () {
        var older = new Configuration(
            testOn: new PlatformSelector.parse("vm"));
        var newer = new Configuration(
            testOn: new PlatformSelector.parse("linux"));
        var merged = older.merge(newer);
        expect(merged.testOn,
            equals(new PlatformSelector.parse("vm && linux")));
      });
    });

    group("for include and excludeTags", () {
      test("if neither is defined, preserves the default", () {
        var merged = new Configuration().merge(new Configuration());
        expect(merged.includeTags, equals(BooleanSelector.all));
        expect(merged.excludeTags, equals(BooleanSelector.none));
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = new Configuration(
                includeTags: new BooleanSelector.parse("foo || bar"),
                excludeTags: new BooleanSelector.parse("baz || bang"))
            .merge(new Configuration());

        expect(merged.includeTags,
            equals(new BooleanSelector.parse("foo || bar")));
        expect(merged.excludeTags,
            equals(new BooleanSelector.parse("baz || bang")));
      });

      test("if only the new configuration's is defined, uses it", () {
        var merged = new Configuration().merge(new Configuration(
            includeTags: new BooleanSelector.parse("foo || bar"),
            excludeTags: new BooleanSelector.parse("baz || bang")));

        expect(merged.includeTags,
            equals(new BooleanSelector.parse("foo || bar")));
        expect(merged.excludeTags,
            equals(new BooleanSelector.parse("baz || bang")));
      });

      test("if both are defined, unions or intersects them", () {
        var older = new Configuration(
            includeTags: new BooleanSelector.parse("foo || bar"),
            excludeTags: new BooleanSelector.parse("baz || bang"));
        var newer = new Configuration(
            includeTags: new BooleanSelector.parse("blip"),
            excludeTags: new BooleanSelector.parse("qux"));
        var merged = older.merge(newer);

        expect(merged.includeTags,
            equals(new BooleanSelector.parse("(foo || bar) && blip")));
        expect(merged.excludeTags,
            equals(new BooleanSelector.parse("(baz || bang) || qux")));
      });
    });

    group("for tags", () {
      test("merges each nested configuration", () {
        var merged = new Configuration(
          tags: {
            new BooleanSelector.parse("foo"):
                new Configuration(verboseTrace: true),
            new BooleanSelector.parse("bar"): new Configuration(jsTrace: true)
          }
        ).merge(new Configuration(
          tags: {
            new BooleanSelector.parse("bar"): new Configuration(jsTrace: false),
            new BooleanSelector.parse("baz"): new Configuration(skip: true)
          }
        ));

        expect(merged.tags[new BooleanSelector.parse("foo")].verboseTrace,
            isTrue);
        expect(merged.tags[new BooleanSelector.parse("bar")].jsTrace, isFalse);
        expect(merged.tags[new BooleanSelector.parse("baz")].skip, isTrue);
      });
    });

    group("for timeout", () {
      test("if neither is defined, preserves the default", () {
        var merged = new Configuration().merge(new Configuration());
        expect(merged.timeout, equals(new Timeout.factor(1)));
      });

      test("if only the old configuration's is defined, uses it", () {
        var merged = new Configuration(timeout: new Timeout.factor(2))
            .merge(new Configuration());
        expect(merged.timeout, equals(new Timeout.factor(2)));
      });

      test("if only the new configuration's is defined, uses it", () {
        var merged = new Configuration()
            .merge(new Configuration(timeout: new Timeout.factor(2)));
        expect(merged.timeout, equals(new Timeout.factor(2)));
      });

      test("if both are defined, merges them", () {
        var older = new Configuration(timeout: new Timeout.factor(2));
        var newer = new Configuration(timeout: new Timeout.factor(3));
        var merged = older.merge(newer);
        expect(merged.timeout, equals(new Timeout.factor(6)));
      });

      test("if the merge conflicts, prefers the new value", () {
        var older = new Configuration(
            timeout: new Timeout(new Duration(seconds: 1)));
        var newer = new Configuration(
            timeout: new Timeout(new Duration(seconds: 2)));
        var merged = older.merge(newer);
        expect(merged.timeout, equals(new Timeout(new Duration(seconds: 2))));
      });
    });

    group("for onPlatform", () {
      test("merges each nested configuration", () {
        var merged = new Configuration(
          onPlatform: {
            new PlatformSelector.parse("vm"): new Configuration(verboseTrace: true),
            new PlatformSelector.parse("chrome"): new Configuration(jsTrace: true)
          }
        ).merge(new Configuration(
          onPlatform: {
            new PlatformSelector.parse("chrome"): new Configuration(jsTrace: false),
            new PlatformSelector.parse("firefox"): new Configuration(skip: true)
          }
        ));

        expect(merged.onPlatform[new PlatformSelector.parse("vm")].verboseTrace,
            isTrue);
        expect(merged.onPlatform[new PlatformSelector.parse("chrome")].jsTrace,
            isFalse);
        expect(merged.onPlatform[new PlatformSelector.parse("firefox")].skip,
            isTrue);
      });
    });
  });
}
