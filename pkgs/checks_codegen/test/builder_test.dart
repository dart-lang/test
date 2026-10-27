// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:checks/checks.dart';
import 'package:checks_codegen/src/builder.dart';
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
        flattenOutput: true,
      );
      final checksOutput = readerWriter.testing.readString(
        AssetId('a', 'test/some_test.checks.dart'),
      );
      check(checksOutput).containsInOrder([
        "import 'package:checks/checks.dart';",
        "import 'package:checks/context.dart' as _i1;",
        "import 'bar.dart' as _i3;",
        "import 'foo.dart' as _i2;",
        'extension FooChecks on _i1.Subject<_i2.Foo> {',
        '  _i1.Subject<_i3.Bar> get barField => '
            "has((v) => v.barField, 'barField');",
        '  _i1.Subject<int> get intField => has((v) => '
            "v.intField, 'intField');",
        '}',
      ]);
    });

    test('can build with an export', () async {
      await testBuilder(
        builder,
        {
          'a|test/some_test.dart': '''
import 'package:checks_codegen/checks_codegen.dart';

import 'foo.dart';

@CheckExtensions([Foo])
export 'some_test.checks.dart';
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
        flattenOutput: true,
      );
      final checksOutput = readerWriter.testing.readString(
        AssetId('a', 'test/some_test.checks.dart'),
      );
      check(checksOutput).containsInOrder([
        "import 'package:checks/checks.dart';",
        "import 'package:checks/context.dart' as _i1;",
        "import 'bar.dart' as _i3;",
        "import 'foo.dart' as _i2;",
        'extension FooChecks on _i1.Subject<_i2.Foo> {',
        '  _i1.Subject<_i3.Bar> get barField => '
            "has((v) => v.barField, 'barField');",
        '  _i1.Subject<int> get intField => '
            "has((v) => v.intField, 'intField');",
        '}',
      ]);
    });

    test('fails if the annotation is not on an import or export', () async {
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
        .it()..contains(
          'must annotate an import or export of some_test.checks.dart',
        ),
      );
    });

    test(
      'fails if the annotation is not an import or export to the generated file',
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
          .it()..contains(
            'must annotate an import or export of some_test.checks.dart',
          ),
        );
      },
    );

    test(
      'includes function typed fields and omits methods and setters',
      () async {
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
    int get intField;
    final void Function() callback;
    final Bar Function(Bar, [Bar?]) positional;
    final void Function({required Bar bar, int? count})? named;
    void method();
    set setterOnly(int value);
}
''',
            'a|test/bar.dart': '''
abstract class Bar {}
''',
          },
          readerWriter: readerWriter,
          flattenOutput: true,
        );
        final checksOutput = readerWriter.testing.readString(
          AssetId('a', 'test/some_test.checks.dart'),
        );
        check(checksOutput)
          ..containsInOrder([
            "import 'package:checks/checks.dart';",
            "import 'package:checks/context.dart' as _i1;",
            "import 'bar.dart' as _i3;",
            "import 'foo.dart' as _i2;",
            'extension FooChecks on _i1.Subject<_i2.Foo> {',
            '  _i1.Subject<int> get intField => has((v) => '
                "v.intField, 'intField');",
            '  _i1.Subject<void Function()> get callback =>',
            "      has((v) => v.callback, 'callback');",
            '  _i1.Subject<_i3.Bar Function(_i3.Bar, [_i3.Bar?])> get positional =>',
            "      has((v) => v.positional, 'positional');",
            '  _i1.Subject<void Function({required _i3.Bar bar, int? count})?> '
                'get named =>',
            "      has((v) => v.named, 'named');",
            '}',
          ])
          ..not(.it()..contains('method'))
          ..not(.it()..contains('setterOnly'));
      },
    );

    test('uses bounds for type parameters of the class', () async {
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

abstract class Foo<T extends Bar, S> {
    final T bounded;
    final S? unbounded;
    final List<T> list;
    final void Function(T) callback;
}
''',
          'a|test/bar.dart': '''
abstract class Bar {}
''',
        },
        readerWriter: readerWriter,
        flattenOutput: true,
      );
      final checksOutput = readerWriter.testing.readString(
        AssetId('a', 'test/some_test.checks.dart'),
      );
      check(checksOutput).containsInOrder([
        "import 'package:checks/checks.dart';",
        "import 'package:checks/context.dart' as _i1;",
        "import 'bar.dart' as _i3;",
        "import 'foo.dart' as _i2;",
        'extension FooChecks on _i1.Subject<_i2.Foo> {',
        '  _i1.Subject<_i3.Bar> get bounded => '
            "has((v) => v.bounded, 'bounded');",
        '  _i1.Subject<dynamic> get unbounded => '
            "has((v) => v.unbounded, 'unbounded');",
        '  _i1.Subject<List<_i3.Bar>> get list => '
            "has((v) => v.list, 'list');",
        '  _i1.Subject<void Function(_i3.Bar)> get callback =>',
        "      has((v) => v.callback, 'callback');",
        '}',
      ]);
    });

    test('supports record, generic function, and Never types', () async {
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
    final (Bar, {Bar? named}) record;
    final T Function<T extends Bar>(T) generic;
    final Never never;
}
''',
          'a|test/bar.dart': '''
abstract class Bar {}
''',
        },
        readerWriter: readerWriter,
        flattenOutput: true,
      );
      final checksOutput = readerWriter.testing.readString(
        AssetId('a', 'test/some_test.checks.dart'),
      );
      check(checksOutput).containsInOrder([
        "import 'package:checks/checks.dart';",
        "import 'package:checks/context.dart' as _i1;",
        "import 'bar.dart' as _i3;",
        "import 'foo.dart' as _i2;",
        'extension FooChecks on _i1.Subject<_i2.Foo> {',
        '  _i1.Subject<(_i3.Bar, {_i3.Bar? named})> get record =>',
        "      has((v) => v.record, 'record');",
        '  _i1.Subject<T Function<T extends _i3.Bar>(T)> get generic =>',
        "      has((v) => v.generic, 'generic');",
        "  _i1.Subject<Never> get never => has((v) => v.never, 'never');",
        '}',
      ]);
    });

    test('imports type arguments of field types', () async {
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
import 'baz.dart';

abstract class Foo {
    final Map<Bar, List<Baz?>> nested;
    final List<void Function()> callbacks;
}
''',
          'a|test/bar.dart': '''
abstract class Bar {}
''',
          'a|test/baz.dart': '''
abstract class Baz {}
''',
        },
        readerWriter: readerWriter,
        flattenOutput: true,
      );
      final checksOutput = readerWriter.testing.readString(
        AssetId('a', 'test/some_test.checks.dart'),
      );
      check(checksOutput).containsInOrder([
        "import 'package:checks/checks.dart';",
        "import 'package:checks/context.dart' as _i1;",
        "import 'bar.dart' as _i3;",
        "import 'baz.dart' as _i4;",
        "import 'foo.dart' as _i2;",
        'extension FooChecks on _i1.Subject<_i2.Foo> {',
        '  _i1.Subject<Map<_i3.Bar, List<_i4.Baz?>>> get nested =>',
        "      has((v) => v.nested, 'nested');",
        '  _i1.Subject<List<void Function()>> get callbacks =>',
        "      has((v) => v.callbacks, 'callbacks');",
        '}',
      ]);
    });
  });
}
