// Copyright 2019 Dart Mockito authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@TestOn('vm')
import 'package:build/build.dart';
import 'package:build/experiments.dart';
import 'package:build_test/build_test.dart';
import 'package:meta/meta.dart';
import 'package:mockito/src/builder.dart';
import 'package:package_config/package_config.dart';
import 'package:test/test.dart';

Builder buildMocks(BuilderOptions options) => MockBuilder();

const annotationsAsset = {
  'mockito|lib/annotations.dart': '''
class GenerateMocks {
  final List<Type> classes;

  const GenerateMocks(this.classes);
}
'''
};

const simpleTestAsset = {
  'foo|test/foo_test.dart': '''
import 'package:foo/foo.dart';
import 'package:mockito/annotations.dart';
@GenerateMocks([Foo])
void main() {}
'''
};

void main() {
  test(
      'generates mock for an imported class but does not override private '
      'or static methods or methods w/ zero parameters', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          dynamic a() => 7;
          int _b(int x) => 8;
          static int c(int y) => 9;
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {}
        '''),
      },
    );
  });

  test(
      'generates mock for an imported class but does not override any '
      'extension methods', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        extension X on Foo {
          dynamic x(int m, String n) => n + 1;
        }
        class Foo {}
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {}
        '''),
      },
    );
  });

  test('overrides methods, matching optional positional parameters', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
          void m(int a, [int b, int c = 0]) {}
      }
      '''),
      _containsAllOf('void m(int? a, [int? b, int? c = 0]) =>',
          'super.noSuchMethod(Invocation.method(#m, [a, b, c]));'),
    );
  });

  test('overrides methods, matching named parameters', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
          void m(int a, {int b, int c = 0}) {}
      }
      '''),
      _containsAllOf('void m(int? a, {int? b, int? c = 0}) =>',
          'super.noSuchMethod(Invocation.method(#m, [a], {#b: b, #c: c}));'),
    );
  });

  test('overrides async methods legally', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Future<void> m() async => print(s);
      }
      '''),
      _containsAllOf('_i3.Future<void> m() =>',
          'super.noSuchMethod(Invocation.method(#m, []), Future.value(null));'),
    );
  });

  test('overrides async* methods legally', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Stream<int> m() async* { yield 7; }
      }
      '''),
      _containsAllOf('_i3.Stream<int> m() =>',
          'super.noSuchMethod(Invocation.method(#m, []), Stream.empty());'),
    );
  });

  test('overrides sync* methods legally', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Iterable<int> m() sync* { yield 7; }
      }
      '''),
      _containsAllOf('Iterable<int> m() =>',
          'super.noSuchMethod(Invocation.method(#m, []), []);'),
    );
  });

  test('generates multiple mock classes', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {}
        class Bar {}
        '''),
        'foo|test/foo_test.dart': '''
        import 'package:foo/foo.dart';
        import 'package:mockito/annotations.dart';
        @GenerateMocks([Foo, Bar])
        void main() {}
        '''
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': _containsAllOf(
          'class MockFoo extends _i1.Mock implements _i2.Foo {}',
          'class MockBar extends _i1.Mock implements _i2.Bar {}',
        ),
      },
    );
  });

  test('generates generic mock classes', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo<T, U> {}
        '''),
        'foo|test/foo_test.dart': '''
        import 'package:foo/foo.dart';
        import 'package:mockito/annotations.dart';
        @GenerateMocks([Foo])
        void main() {}
        '''
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': _containsAllOf(
            'class MockFoo<T, U> extends _i1.Mock implements _i2.Foo<T, U> {}'),
      },
    );
  });

  test('generates generic mock classes with type bounds', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {}
        class Bar<T extends Foo> {}
        '''),
        'foo|test/foo_test.dart': '''
        import 'package:foo/foo.dart';
        import 'package:mockito/annotations.dart';
        @GenerateMocks([Foo, Bar])
        void main() {}
        '''
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': _containsAllOf(
          'class MockFoo extends _i1.Mock implements _i2.Foo {}',
          'class MockBar<T extends _i2.Foo> extends _i1.Mock implements _i2.Bar<T> {}',
        ),
      },
    );
  });

  test('writes non-interface types w/o imports', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo<T> {
          void f(dynamic a, int b) {}
          void g(T c) {}
          void h<U>(U d) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo<T> extends _i1.Mock implements _i2.Foo<T> {
          void f(dynamic a, int? b) =>
              super.noSuchMethod(Invocation.method(#f, [a, b]));
          void g(T? c) => super.noSuchMethod(Invocation.method(#g, [c]));
          void h<U>(U? d) => super.noSuchMethod(Invocation.method(#h, [d]));
        }
        '''),
      },
    );
  });

  test('imports libraries for external class types', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        import 'dart:async';
        class Foo {
          dynamic f(List<Foo> list) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic f(List<_i2.Foo>? list) =>
              super.noSuchMethod(Invocation.method(#f, [list]));
        }
        '''),
      },
    );
  });

  test('imports libraries for type aliases with external types', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        import 'dart:async';
        typedef Callback = void Function();
        typedef void Callback2();
        typedef Future<T> Callback3<T>();
        class Foo {
          dynamic f(Callback c) {}
          dynamic g(Callback2 c) {}
          dynamic h(Callback3<Foo> c) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic f(_i2.Callback? c) => super.noSuchMethod(Invocation.method(#f, [c]));
          dynamic g(_i2.Callback2? c) => super.noSuchMethod(Invocation.method(#g, [c]));
          dynamic h(_i2.Callback3<_i2.Foo>? c) =>
              super.noSuchMethod(Invocation.method(#h, [c]));
        }
        '''),
      },
    );
  });

  test('imports libraries for function types with external types', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        import 'dart:async';
        class Foo {
          dynamic f(Foo c()) {}
          dynamic g(void c(Foo f)) {}
          dynamic h(void c(Foo f, [Foo g])) {}
          dynamic i(void c(Foo f, {Foo g})) {}
          dynamic j(Foo Function() c) {}
          dynamic k(void Function(Foo f) c) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic f(_i2.Foo Function() c) =>
              super.noSuchMethod(Invocation.method(#f, [c]));
          dynamic g(void Function(_i2.Foo) c) =>
              super.noSuchMethod(Invocation.method(#g, [c]));
          dynamic h(void Function(_i2.Foo, [_i2.Foo]) c) =>
              super.noSuchMethod(Invocation.method(#h, [c]));
          dynamic i(void Function(_i2.Foo, {_i2.Foo g}) c) =>
              super.noSuchMethod(Invocation.method(#i, [c]));
          dynamic j(_i2.Foo Function() c) =>
              super.noSuchMethod(Invocation.method(#j, [c]));
          dynamic k(void Function(_i2.Foo) c) =>
              super.noSuchMethod(Invocation.method(#k, [c]));
        }
        '''),
      },
    );
  });

  test('widens the type of parameters to be nullable', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          void m(int? a, int b);
        }
        '''),
      _containsAllOf(
          'void m(int? a, int? b) => super.noSuchMethod(Invocation.method(#m, [a, b]));'),
    );
  });

  test(
      'widens the type of potentially non-nullable type variables to be '
      'nullable', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo<T> {
          void m(int? a, T b);
        }
        '''),
      _containsAllOf(
          'void m(int? a, T? b) => super.noSuchMethod(Invocation.method(#m, [a, b]));'),
    );
  });

  test('matches nullability of type arguments of a parameter', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          void m(List<int?> a, List<int> b);
        }
        '''),
      _containsAllOf('void m(List<int?>? a, List<int>? b) =>',
          'super.noSuchMethod(Invocation.method(#m, [a, b]));'),
    );
  });

  test(
      'matches nullability of return type of a generic function-typed '
      'parameter', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          void m(int? Function() a, int Function() b);
        }
        '''),
      // `a` and `b` should be nullable. code_builder needs a fix, allowing a
      // FunctionTypeBuilder to take an `isNullable` value.
      _containsAllOf('void m(int? Function() a, int Function() b) =>',
          'super.noSuchMethod(Invocation.method(#m, [a, b]));'),
    );
  });

  test(
      'matches nullability of parameter types within a generic function-typed '
      'parameter', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          void m(void Function(int?) a, void Function(int) b);
        }
        '''),
      // `a` and `b` should be nullable. code_builder needs a fix, allowing a
      // FunctionTypeBuilder to take an `isNullable` value.
      _containsAllOf('void m(void Function(int?) a, void Function(int) b) =>',
          'super.noSuchMethod(Invocation.method(#m, [a, b]));'),
    );
  });

  test('matches nullability of return type of a function-typed parameter',
      () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          void m(int? a(), int b());
        }
        '''),
      // `a` and `b` should be nullable. code_builder needs a fix, allowing a
      // FunctionTypeBuilder to take an `isNullable` value.
      _containsAllOf('void m(int? Function() a, int Function() b) =>',
          'super.noSuchMethod(Invocation.method(#m, [a, b]));'),
    );
  });

  test(
      'matches nullability of parameter types within a function-typed '
      'parameter', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          void m(void a(int? x), void b(int x));
        }
        '''),
      // `a` and `b` should be nullable. code_builder needs a fix, allowing a
      // FunctionTypeBuilder to take an `isNullable` value.
      _containsAllOf('void m(void Function(int?) a, void Function(int) b) =>',
          'super.noSuchMethod(Invocation.method(#m, [a, b]));'),
    );
  });

  test('matches nullability of a generic parameter', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          void m<T>(T? a, T b);
        }
        '''),
      _containsAllOf(
          'void m<T>(T? a, T? b) => super.noSuchMethod(Invocation.method(#m, [a, b]));'),
    );
  });

  test('matches nullability of a dynamic parameter', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          void m(dynamic a, int b);
        }
        '''),
      _containsAllOf('void m(dynamic a, int? b) =>',
          'super.noSuchMethod(Invocation.method(#m, [a, b]));'),
    );
  });

  test('matches nullability of return types', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        abstract class Foo {
          int f(int a);
          int? g(int a);
          List<int?> h(int a);
          List<int> i(int a);
          j(int a);
          T? k<T extends int>(int a);
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          int f(int? a) => super.noSuchMethod(Invocation.method(#f, [a]), 0);
          int? g(int? a) => super.noSuchMethod(Invocation.method(#g, [a]));
          List<int?> h(int? a) => super.noSuchMethod(Invocation.method(#h, [a]), []);
          List<int> i(int? a) => super.noSuchMethod(Invocation.method(#i, [a]), []);
          dynamic j(int? a) => super.noSuchMethod(Invocation.method(#j, [a]));
          T? k<T extends int>(int? a) => super.noSuchMethod(Invocation.method(#k, [a]));
        }
        '''),
      },
    );
  });

  test('overrides abstract methods', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      abstract class Foo {
        dynamic f(int a);
      }
      '''),
      _containsAllOf(
          'dynamic f(int? a) => super.noSuchMethod(Invocation.method(#f, [a]));'),
    );
  });

  test('does not override methods with all nullable parameters', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
          class Foo {
            void a(int? p) {}
            void b(dynamic p) {}
            void c(var p) {}
            void d(final p) {}
            void e(int Function()? p) {}
          }
          '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
          import 'package:mockito/mockito.dart' as _i1;
          import 'package:foo/foo.dart' as _i2;

          /// A class which mocks [Foo].
          ///
          /// See the documentation for Mockito's code generation for more information.
          class MockFoo extends _i1.Mock implements _i2.Foo {}
          '''),
      },
    );
  });

  test('does not override methods with a void return type', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          void m();
        }
        '''),
      _containsAllOf('class MockFoo extends _i1.Mock implements _i2.Foo {}'),
    );
  });

  test('does not override methods with an implicit dynamic return type',
      () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          m();
        }
        '''),
      _containsAllOf('class MockFoo extends _i1.Mock implements _i2.Foo {}'),
    );
  });

  test('does not override methods with an explicit dynamic return type',
      () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          dynamic m();
        }
        '''),
      _containsAllOf('class MockFoo extends _i1.Mock implements _i2.Foo {}'),
    );
  });

  test('does not override methods with a nullable return type', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          int? m();
        }
        '''),
      _containsAllOf('class MockFoo extends _i1.Mock implements _i2.Foo {}'),
    );
  });

  test('overrides methods with a non-nullable return type', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
        abstract class Foo {
          int m();
        }
        '''),
      _containsAllOf(
          'int m() => super.noSuchMethod(Invocation.method(#m, []), 0);'),
    );
  });

  test('overrides methods with a potentially non-nullable parameter', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo<T> {
          void a(T m) {}
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo<T> extends _i1.Mock implements _i2.Foo<T> {
          void a(T? m) => super.noSuchMethod(Invocation.method(#a, [m]));
        }
        '''),
      },
    );
  });

  test('overrides generic methods', () async {
    await _testWithNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {
          dynamic f<T>(int a) {}
          dynamic g<T extends Foo>(int a) {}
        }
        '''),
      },
      outputs: {
        // TODO(srawlins): The getter will appear when it has a non-nullable
        // return type.
        'foo|test/foo_test.mocks.dart': dedent(r'''
        import 'package:mockito/mockito.dart' as _i1;
        import 'package:foo/foo.dart' as _i2;

        /// A class which mocks [Foo].
        ///
        /// See the documentation for Mockito's code generation for more information.
        class MockFoo extends _i1.Mock implements _i2.Foo {
          dynamic f<T>(int? a) => super.noSuchMethod(Invocation.method(#f, [a]));
          dynamic g<T extends _i2.Foo>(int? a) =>
              super.noSuchMethod(Invocation.method(#g, [a]));
        }
        '''),
      },
    );
  });

  test('overrides non-nullable instance getters', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        int get m => 7;
      }
      '''),
      _containsAllOf(
          'int get m => super.noSuchMethod(Invocation.getter(#m), 0);'),
    );
  });

  test('does not override nullable instance getters', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        int? get m => 7;
      }
      '''),
      _containsAllOf('class MockFoo extends _i1.Mock implements _i2.Foo {}'),
    );
  });

  test('overrides non-nullable instance setters', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        void set m(int a) {}
      }
      '''),
      _containsAllOf(
          'set m(int? a) => super.noSuchMethod(Invocation.setter(#m, [a]));'),
    );
  });

  test('does not override nullable instance setters', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        void set m(int? a) {}
      }
      '''),
      _containsAllOf('class MockFoo extends _i1.Mock implements _i2.Foo {}'),
    );
  });

  test('overrides non-nullable fields', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        int m;
      }
      '''),
      _containsAllOf(
          'int get m => super.noSuchMethod(Invocation.getter(#m), 0);',
          'set m(int? _m) => super.noSuchMethod(Invocation.setter(#m, [_m]));'),
    );
  });

  test('overrides final non-nullable fields', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        final int m;
        Foo(this.m);
      }
      '''),
      _containsAllOf(
          'int get m => super.noSuchMethod(Invocation.getter(#m), 0);'),
    );
  });

  test('does not override nullable fields', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        int? m;
      }
      '''),
      _containsAllOf('class MockFoo extends _i1.Mock implements _i2.Foo {}'),
    );
  });

  test('does not override private fields', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        int _a;
      }
      '''),
      _containsAllOf('class MockFoo extends _i1.Mock implements _i2.Foo {}'),
    );
  });

  test('does not override static fields', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        static int b;
      }
      '''),
      _containsAllOf('class MockFoo extends _i1.Mock implements _i2.Foo {}'),
    );
  });

  test('overrides binary operators', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        int operator +(Foo other) => 7;
      }
      '''),
      _containsAllOf('int operator +(_i2.Foo? other) =>',
          'super.noSuchMethod(Invocation.method(#+, [other]), 0);'),
    );
  });

  test('overrides index operators', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        int operator [](int x) => 7;
      }
      '''),
      _containsAllOf(
          'int operator [](int? x) => super.noSuchMethod(Invocation.method(#[], [x]), 0);'),
    );
  });

  test('overrides unary operators', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        int operator ~() => 7;
      }
      '''),
      _containsAllOf(
          'int operator ~() => super.noSuchMethod(Invocation.method(#~, []), 0);'),
    );
  });

  test('creates dummy non-null bool return value', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        bool m() => false;
      }
      '''),
      _containsAllOf(
          'bool m() => super.noSuchMethod(Invocation.method(#m, []), false);'),
    );
  });

  test('creates dummy non-null double return value', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        double m() => 3.14;
      }
      '''),
      _containsAllOf(
          'double m() => super.noSuchMethod(Invocation.method(#m, []), 0.0);'),
    );
  });

  test('creates dummy non-null int return value', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        int m() => 7;
      }
      '''),
      _containsAllOf(
          'int m() => super.noSuchMethod(Invocation.method(#m, []), 0);'),
    );
  });

  test('creates dummy non-null String return value', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        String m() => "Hello";
      }
      '''),
      _containsAllOf(
          "String m() => super.noSuchMethod(Invocation.method(#m, []), '');"),
    );
  });

  test('creates dummy non-null List return value', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        List<Foo> m() => [Foo()];
      }
      '''),
      _containsAllOf(
          'List<_i2.Foo> m() => super.noSuchMethod(Invocation.method(#m, []), []);'),
    );
  });

  test('creates dummy non-null Set return value', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Set<Foo> m() => {Foo()};
      }
      '''),
      _containsAllOf(
          'Set<_i2.Foo> m() => super.noSuchMethod(Invocation.method(#m, []), {});'),
    );
  });

  test('creates dummy non-null Map return value', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Map<int, Foo> m() => {7: Foo()};
      }
      '''),
      _containsAllOf(
          'Map<int, _i2.Foo> m() => super.noSuchMethod(Invocation.method(#m, []), {});'),
    );
  });

  test('creates dummy non-null return values for Futures of known core classes',
      () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Future<bool> m() async => false;
      }
      '''),
      _containsAllOf('_i3.Future<bool> m() =>',
          'super.noSuchMethod(Invocation.method(#m, []), Future.value(false));'),
    );
  });

  test('creates dummy non-null return values for unknown classes', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Bar m() => Bar('name');
      }
      class Bar {
        final String name;
        Bar(this.name);
      }
      '''),
      _containsAllOf(
          '_i2.Bar m() => super.noSuchMethod(Invocation.method(#m, []), _FakeBar());'),
    );
  });

  test('deduplicates fake classes', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Bar m1() => Bar('name1');
        Bar m2() => Bar('name2');
      }
      class Bar {
        final String name;
        Bar(this.name);
      }
      '''),
      dedent(r'''
      import 'package:mockito/mockito.dart' as _i1;
      import 'package:foo/foo.dart' as _i2;

      class _FakeBar extends _i1.Fake implements _i2.Bar {}

      /// A class which mocks [Foo].
      ///
      /// See the documentation for Mockito's code generation for more information.
      class MockFoo extends _i1.Mock implements _i2.Foo {
        _i2.Bar m1() => super.noSuchMethod(Invocation.method(#m1, []), _FakeBar());
        _i2.Bar m2() => super.noSuchMethod(Invocation.method(#m2, []), _FakeBar());
      }
      '''),
    );
  });

  test('creates dummy non-null return values for enums', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Bar m1() => Bar('name');
      }
      enum Bar {
        one,
        two,
      }
      '''),
      _containsAllOf(
          '_i2.Bar m1() => super.noSuchMethod(Invocation.method(#m1, []), _i2.Bar.one);'),
    );
  });

  test(
      'creates a dummy non-null return function-typed value, with optional '
      'parameters', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        void Function(int, [String]) m() => (int i, [String s]) {};
      }
      '''),
      _containsAllOf('void Function(int, [String]) m() => super',
          '.noSuchMethod(Invocation.method(#m, []), (int __p0, [String __p1]) {});'),
    );
  });

  test(
      'creates a dummy non-null return function-typed value, with named '
      'parameters', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        void Function(Foo, {bool b}) m() => (Foo f, {bool b}) {};
      }
      '''),
      _containsAllOf('void Function(_i2.Foo, {bool b}) m() => super',
          '.noSuchMethod(Invocation.method(#m, []), (_i2.Foo __p0, {bool b}) {});'),
    );
  });

  test(
      'creates a dummy non-null return function-typed value, with non-core '
      'return type', () async {
    await _expectSingleNonNullableOutput(
      dedent(r'''
      class Foo {
        Foo Function() m() => () => Foo();
      }
      '''),
      _containsAllOf('_i2.Foo Function() m() =>',
          'super.noSuchMethod(Invocation.method(#m, []), () => _FakeFoo());'),
    );
  });

  test('throws when GenerateMocks references an unresolved type', () async {
    expectBuilderThrows(
      assets: {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {}
        '''),
        'foo|test/foo_test.dart': dedent('''
        // missing foo.dart import.
        import 'package:mockito/annotations.dart';
        @GenerateMocks([List, Foo])
        void main() {}
        '''),
      },
      message: 'The "classes" argument has unknown types',
    );
  });

  test('throws when GenerateMocks references a non-type', () async {
    expectBuilderThrows(
      assets: {
        ...annotationsAsset,
        'foo|lib/foo.dart': dedent(r'''
        class Foo {}
        '''),
        'foo|test/foo_test.dart': dedent('''
        // missing foo.dart import.
        import 'package:mockito/annotations.dart';
        @GenerateMocks([7])
        void main() {}
        '''),
      },
      message: 'The "classes" argument includes a non-type: int (7)',
    );
  });

  test('throws when GenerateMocks references a typedef', () async {
    expectBuilderThrows(
      assets: {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        typedef Foo = void Function();
        '''),
      },
      message: 'The "classes" argument includes a typedef: Foo',
    );
  });

  test('throws when GenerateMocks references an enum', () async {
    expectBuilderThrows(
      assets: {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        enum Foo {}
        '''),
      },
      message: 'The "classes" argument includes an enum: Foo',
    );
  });

  test('given a pre-non-nullable library, does not override any members',
      () async {
    await _testPreNonNullable(
      {
        ...annotationsAsset,
        ...simpleTestAsset,
        'foo|lib/foo.dart': dedent(r'''
        abstract class Foo {
          int f(int a);
        }
        '''),
      },
      outputs: {
        'foo|test/foo_test.mocks.dart': _containsAllOf(
            'class MockFoo extends _i1.Mock implements _i2.Foo {}'),
      },
    );
  });
}

/// Test [MockBuilder] in a package which has not opted into the non-nullable
/// type system.
///
/// Whether the non-nullable experiment is enabled depends on the SDK executing
/// this test, but that does not affect the opt-in state of the package under
/// test.
Future<void> _testPreNonNullable(Map<String, String> sourceAssets,
    {Map<String, /*String|Matcher<String>*/ dynamic> outputs}) async {
  var packageConfig = PackageConfig([
    Package('foo', Uri.file('/foo/'),
        packageUriRoot: Uri.file('/foo/lib/'),
        languageVersion: LanguageVersion(2, 7))
  ]);
  await testBuilder(buildMocks(BuilderOptions({})), sourceAssets,
      outputs: outputs, packageConfig: packageConfig);
}

/// Test [MockBuilder] in a package which has opted into the non-nullable type
/// system, and with the non-nullable experiment enabled.
Future<void> _testWithNonNullable(Map<String, String> sourceAssets,
    {Map<String, /*String|Matcher<String>*/ dynamic> outputs}) async {
  var packageConfig = PackageConfig([
    Package('foo', Uri.file('/foo/'),
        packageUriRoot: Uri.file('/foo/lib/'),
        languageVersion: LanguageVersion(2, 9))
  ]);
  await withEnabledExperiments(
    () async => await testBuilder(buildMocks(BuilderOptions({})), sourceAssets,
        outputs: outputs, packageConfig: packageConfig),
    ['non-nullable'],
  );
}

/// Test [MockBuilder] on a single source file, in a package which has opted
/// into the non-nullable type system, and with the non-nullable experiment
/// enabled.
Future<void> _expectSingleNonNullableOutput(
    String sourceAssetText,
    /*String|Matcher<String>*/ dynamic output) async {
  var packageConfig = PackageConfig([
    Package('foo', Uri.file('/foo/'),
        packageUriRoot: Uri.file('/foo/lib/'),
        languageVersion: LanguageVersion(2, 9))
  ]);

  await withEnabledExperiments(
    () async => await testBuilder(
        buildMocks(BuilderOptions({})),
        {
          ...annotationsAsset,
          ...simpleTestAsset,
          'foo|lib/foo.dart': sourceAssetText,
        },
        outputs: {'foo|test/foo_test.mocks.dart': output},
        packageConfig: packageConfig),
    ['non-nullable'],
  );
}

TypeMatcher<List<int>> _containsAllOf(a, [b]) => decodedMatches(
    b == null ? allOf(contains(a)) : allOf(contains(a), contains(b)));

/// Expect that [testBuilder], given [assets], throws an
/// [InvalidMockitoAnnotationException] with a message containing [message].
void expectBuilderThrows(
    {@required Map<String, String> assets, @required String message}) {
  expect(
      () async => await testBuilder(buildMocks(BuilderOptions({})), assets),
      throwsA(TypeMatcher<InvalidMockitoAnnotationException>()
          .having((e) => e.message, 'message', contains(message))));
}

/// Dedent [input], so that each line is shifted to the left, so that the first
/// line is at the 0 column.
String dedent(String input) {
  final indentMatch = RegExp(r'^(\s*)').firstMatch(input);
  final indent = ''.padRight(indentMatch.group(1).length);
  return input.splitMapJoin('\n',
      onNonMatch: (s) => s.replaceFirst(RegExp('^$indent'), ''));
}
