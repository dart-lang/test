// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:checks/checks.dart';
import 'package:checks_codegen/src/builder.dart';
import 'package:matcher/matcher.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('ChecksBuilder', () {
    late Builder builder;
    late TestReaderWriter readerWriter;

    setUpAll(() async {
      readerWriter = TestReaderWriter(rootPackage: 'a');
      await readerWriter.testing.loadIsolateSources();
    });

    setUp(() async {
      builder = checksBuilder(null);
    });

    test('can build', () async {
      await testBuilder(
        builder,
        {
          'a|test/some_test.dart': '''
import 'package:checks_codegen/checks_codegen.dart';

import 'foo.dart';

@CheckExtensions([Foo])
import 'some_test.checks.dart';
''',
          'a|test/foo.dart': '''
import 'bar.dart';

abstract class Foo {
    final Bar barField;
    int get intField;
}
''',
          'a|test/bar.dart': '''
abstract class Bar {}
''',
        },
        readerWriter: readerWriter,
        outputs: {
          'a|test/some_test.checks.dart': decodedMatches(
            stringContainsInOrder([
              "import 'package:checks/context.dart' as _i1;",
              "import 'foo.dart' as _i2;",
              "import 'bar.dart' as _i3;",
              "import 'package:checks/checks.dart';",
              'extension FooChecks on _i1.Subject<_i2.Foo> {',
              "  _i1.Subject<_i3.Bar> get barField => has((v) => v.barField, 'barField');",
              "  _i1.Subject<int> get intField => has((v) => v.intField, 'intField');",
              '}',
            ]),
          ),
        },
      );
    });

    test('fails if the annotation is not on an import', () async {
      final result = await testBuilder(builder, {
        'a|test/some_test.dart': '''
import 'package:checks_codegen/checks_codegen.dart';

import 'foo.dart';

import 'some_test.checks.dart';

@CheckExtensions([Foo])
void main() {
}
''',
        'a|test/foo.dart': '''
abstract class Foo {
    int get intField;
}
''',
      }, readerWriter: readerWriter);
      check(result.errors).any(
        (e) => e.contains('must annotate an import of some_test.checks.dart'),
      );
    });

    test(
      'fails if the annotation is not an import to the generated file',
      () async {
        final result = await testBuilder(builder, {
          'a|test/some_test.dart': '''
import 'package:checks_codegen/checks_codegen.dart';

import 'foo.dart';

@CheckExtensions([Foo])
import 'wrong_test.checks.dart';

void main() {
}
''',
          'a|test/foo.dart': '''
abstract class Foo {
    int get intField;
}
''',
        }, readerWriter: readerWriter);
        check(result.errors).any(
          (e) => e.contains('must annotate an import of some_test.checks.dart'),
        );
      },
    );
  });
}
