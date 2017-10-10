// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:test/src/util/exit_codes.dart' as exit_codes;
import 'package:test/test.dart';

import '../../io.dart';

void main() {
  group("define_platforms", () {
    group("errors", () {
      test("rejects a non-map value", () async {
        await d.file("dart_test.yaml", "define_platforms: 12").create();

        var test = await runTest([]);
        expect(test.stderr,
            containsInOrder(["define_platforms must be a map.", "^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("rejects a non-string key", () async {
        await d.file("dart_test.yaml", "define_platforms: {12: null}").create();

        var test = await runTest([]);
        expect(test.stderr,
            containsInOrder(["Platform identifier must be a string.", "^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("rejects a non-identifier-like key", () async {
        await d
            .file("dart_test.yaml", "define_platforms: {foo bar: null}")
            .create();

        var test = await runTest([]);
        expect(
            test.stderr,
            containsInOrder([
              "Platform identifier must be an (optionally hyphenated) Dart "
                  "identifier.",
              "^^^^^^^"
            ]));
        await test.shouldExit(exit_codes.data);
      });

      test("rejects a non-map definition", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chromium: 12
        """).create();

        var test = await runTest([]);
        expect(test.stderr,
            containsInOrder(["Platform definition must be a map.", "^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("requires a name key", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chromium:
              extends: chrome
              settings: {}
        """).create();

        var test = await runTest([]);
        expect(
            test.stderr,
            containsInOrder(
                ['Missing required field "name".', "^^^^^^^^^^^^^^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("name must be a string", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chromium:
              name: null
              extends: chrome
              settings: {}
        """).create();

        var test = await runTest([]);
        expect(test.stderr, containsInOrder(['Must be a string.', "^^^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("requires an extends key", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chromium:
              name: Chromium
              settings: {}
        """).create();

        var test = await runTest([]);
        expect(
            test.stderr,
            containsInOrder(
                ['Missing required field "extends".', "^^^^^^^^^^^^^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("extends must be a string", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chromium:
              name: Chromium
              extends: null
              settings: {}
        """).create();

        var test = await runTest([]);
        expect(test.stderr,
            containsInOrder(['Platform parent must be a string.', "^^^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("extends must be identifier-like", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chromium:
              name: Chromium
              extends: foo bar
              settings: {}
        """).create();

        var test = await runTest([]);
        expect(
            test.stderr,
            containsInOrder([
              "Platform parent must be an (optionally hyphenated) Dart "
                  "identifier.",
              "^^^^^^^"
            ]));
        await test.shouldExit(exit_codes.data);
      });

      test("requires a settings key", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chromium:
              name: Chromium
              extends: chrome
        """).create();

        var test = await runTest([]);
        expect(
            test.stderr,
            containsInOrder(
                ['Missing required field "settings".', "^^^^^^^^^^^^^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("settings must be a map", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chromium:
              name: Chromium
              extends: chrome
              settings: null
        """).create();

        var test = await runTest([]);
        expect(test.stderr, containsInOrder(['Must be a map.', "^^^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("the new platform may not override an existing platform", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chrome:
              name: Chromium
              extends: firefox
              settings: {}
        """).create();

        await d.dir("test").create();

        var test = await runTest([]);
        expect(
            test.stderr,
            containsInOrder([
              'The platform "chrome" already exists. Use override_platforms to '
                  'override it.',
              "^^^^^^"
            ]));
        await test.shouldExit(exit_codes.data);
      });

      test("the new platform must extend an existing platform", () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            chromium:
              name: Chromium
              extends: foobar
              settings: {}
        """).create();

        await d.dir("test").create();

        var test = await runTest([]);
        expect(test.stderr, containsInOrder(['Unknown platform.', "^^^^^^"]));
        await test.shouldExit(exit_codes.data);
      });

      test("the new platform can't extend an uncustomizable platform",
          () async {
        await d.file("dart_test.yaml", """
          define_platforms:
            myvm:
              name: My VM
              extends: vm
              settings: {}
        """).create();

        // We have to actually run a test with our custom platform, since
        // otherwise it won't load the VM platform at all and so won't be able
        // to tell whether it's customizable.
        await d.file("test.dart", "void main() {}").create();

        var test = await runTest(["-p", "myvm", "test.dart"]);
        expect(test.stdout,
            containsInOrder(['The "vm" platform can\'t be customized.', "^^"]));
        await test.shouldExit(1);
      });
    });
  });
}
