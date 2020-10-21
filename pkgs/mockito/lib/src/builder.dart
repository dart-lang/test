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

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart' as analyzer;
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

/// For a source Dart library, generate the mocks referenced therein.
///
/// Given an input library, 'foo.dart', this builder will search the top-level
/// elements for an annotation, `@GenerateMocks`, from the mockito package. For
/// example:
///
/// ```dart
/// @GenerateMocks([Foo])
/// void main() {}
/// ```
///
/// If this builder finds any classes to mock (for example, `Foo`, above), it
/// will produce a "'.mocks.dart' file with such mocks. In this example,
/// 'foo.mocks.dart' will be created.
class MockBuilder implements Builder {
  @override
  Future<void> build(BuildStep buildStep) async {
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) return;
    final entryLib = await buildStep.inputLibrary;
    if (entryLib == null) return;
    final sourceLibIsNonNullable = entryLib.isNonNullableByDefault;
    final mockLibraryAsset = buildStep.inputId.changeExtension('.mocks.dart');
    final mockTargetGatherer = _MockTargetGatherer(entryLib);

    final mockLibrary = Library((b) {
      var mockLibraryInfo = _MockLibraryInfo(mockTargetGatherer._mockTargets,
          sourceLibIsNonNullable: sourceLibIsNonNullable,
          typeProvider: entryLib.typeProvider,
          typeSystem: entryLib.typeSystem);
      b.body.addAll(mockLibraryInfo.fakeClasses);
      b.body.addAll(mockLibraryInfo.mockClasses);
    });

    if (mockLibrary.body.isEmpty) {
      // Nothing to mock here!
      return;
    }

    final emitter =
        DartEmitter.scoped(useNullSafetySyntax: sourceLibIsNonNullable);
    final mockLibraryContent =
        DartFormatter().format(mockLibrary.accept(emitter).toString());

    await buildStep.writeAsString(mockLibraryAsset, mockLibraryContent);
  }

  @override
  final buildExtensions = const {
    '.dart': ['.mocks.dart']
  };
}

class _MockTarget {
  /// The class to be mocked.
  final analyzer.InterfaceType classType;

  /// The desired name of the mock class.
  final String mockName;

  final bool returnNullOnMissingStub;

  _MockTarget(this.classType, this.mockName, {this.returnNullOnMissingStub});

  ClassElement get classElement => classType.element;
}

/// This class gathers and verifies mock targets referenced in `GenerateMocks`
/// annotations.
class _MockTargetGatherer {
  final LibraryElement _entryLib;

  final List<_MockTarget> _mockTargets;

  _MockTargetGatherer._(this._entryLib, this._mockTargets) {
    _checkClassesToMockAreValid();
  }

  /// Searches the top-level elements of [entryLib] for `GenerateMocks`
  /// annotations and creates a [_MockTargetGatherer] with all of the classes
  /// identified as mocking targets.
  factory _MockTargetGatherer(LibraryElement entryLib) {
    final mockTargets = <_MockTarget>{};

    for (final element in entryLib.topLevelElements) {
      // TODO(srawlins): Re-think the idea of multiple @GenerateMocks
      // annotations, on one element or even on different elements in a library.
      for (final annotation in element.metadata) {
        if (annotation == null) continue;
        if (annotation.element is! ConstructorElement) continue;
        final annotationClass = annotation.element.enclosingElement.name;
        // TODO(srawlins): check library as well.
        if (annotationClass == 'GenerateMocks') {
          mockTargets
              .addAll(_mockTargetsFromGenerateMocks(annotation, entryLib));
        }
      }
    }

    return _MockTargetGatherer._(entryLib, mockTargets.toList());
  }

  static Iterable<_MockTarget> _mockTargetsFromGenerateMocks(
      ElementAnnotation annotation, LibraryElement entryLib) {
    final generateMocksValue = annotation.computeConstantValue();
    final classesField = generateMocksValue.getField('classes');
    if (classesField.isNull) {
      throw InvalidMockitoAnnotationException(
          'The GenerateMocks "classes" argument is missing, includes an '
          'unknown type, or includes an extension');
    }
    final mockTargets = <_MockTarget>[];
    for (var objectToMock in classesField.toListValue()) {
      final typeToMock = objectToMock.toTypeValue();
      if (typeToMock == null) {
        throw InvalidMockitoAnnotationException(
            'The "classes" argument includes a non-type: $objectToMock');
      }
      if (typeToMock.isDynamic) {
        throw InvalidMockitoAnnotationException(
            'Mockito cannot mock `dynamic`');
      }
      final type = _determineDartType(typeToMock, entryLib.typeProvider);
      final mockName = 'Mock${type.element.name}';
      mockTargets
          .add(_MockTarget(type, mockName, returnNullOnMissingStub: false));
    }
    final customMocksField = generateMocksValue.getField('customMocks');
    if (customMocksField != null && !customMocksField.isNull) {
      for (var mockSpec in customMocksField.toListValue()) {
        final mockSpecType = mockSpec.type;
        assert(mockSpecType.typeArguments.length == 1);
        final typeToMock = mockSpecType.typeArguments.single;
        if (typeToMock.isDynamic) {
          throw InvalidMockitoAnnotationException(
              'Mockito cannot mock `dynamic`; be sure to declare type '
              'arguments on MockSpec(), in @GenerateMocks.');
        }
        var type = _determineDartType(typeToMock, entryLib.typeProvider);
        final mockName = mockSpec.getField('mockName').toSymbolValue() ??
            'Mock${type.element.name}';
        final returnNullOnMissingStub =
            mockSpec.getField('returnNullOnMissingStub').toBoolValue();
        mockTargets.add(_MockTarget(type, mockName,
            returnNullOnMissingStub: returnNullOnMissingStub));
      }
    }
    return mockTargets;
  }

  /// Map the values passed to the GenerateMocks annotation to the classes which
  /// they represent.
  ///
  /// This function is responsible for ensuring that each value is an
  /// appropriate target for mocking. It will throw an
  /// [InvalidMockitoAnnotationException] under various conditions.
  static analyzer.InterfaceType _determineDartType(
      analyzer.DartType typeToMock, TypeProvider typeProvider) {
    final elementToMock = typeToMock.element;
    if (elementToMock is ClassElement) {
      if (elementToMock.isEnum) {
        throw InvalidMockitoAnnotationException(
            'Mockito cannot mock an enum: ${elementToMock.displayName}');
      }
      if (typeProvider.nonSubtypableClasses.contains(elementToMock)) {
        throw InvalidMockitoAnnotationException(
            'Mockito cannot mock a non-subtypable type: '
            '${elementToMock.displayName}. It is illegal to subtype this '
            'type.');
      }
      if (elementToMock.isPrivate) {
        throw InvalidMockitoAnnotationException(
            'Mockito cannot mock a private type: '
            '${elementToMock.displayName}.');
      }
      var typeParameterErrors =
          _checkTypeParameters(elementToMock.typeParameters, elementToMock);
      if (typeParameterErrors.isNotEmpty) {
        var joinedMessages =
            typeParameterErrors.map((m) => '    $m').join('\n');
        throw InvalidMockitoAnnotationException(
            'Mockito cannot generate a valid mock class which implements '
            "'${elementToMock.displayName}' for the following reasons:\n"
            '$joinedMessages');
      }
      return typeToMock as analyzer.InterfaceType;
    } else if (elementToMock is FunctionTypeAliasElement) {
      throw InvalidMockitoAnnotationException('Mockito cannot mock a typedef: '
          '${elementToMock.displayName}');
    } else if (elementToMock is GenericFunctionTypeElement &&
        elementToMock.enclosingElement is FunctionTypeAliasElement) {
      throw InvalidMockitoAnnotationException('Mockito cannot mock a typedef: '
          '${elementToMock.enclosingElement.displayName}');
    } else {
      throw InvalidMockitoAnnotationException(
          'Mockito cannot mock a non-class: ${elementToMock.displayName}');
    }
  }

  void _checkClassesToMockAreValid() {
    var classesInEntryLib =
        _entryLib.topLevelElements.whereType<ClassElement>();
    var classNamesToMock = <String, ClassElement>{};
    var uniqueNameSuggestion =
        "use the 'customMocks' argument in @GenerateMocks to specify a unique "
        'name';
    for (final mockTarget in _mockTargets) {
      var name = mockTarget.mockName;
      if (classNamesToMock.containsKey(name)) {
        var firstSource = classNamesToMock[name].source.fullName;
        var secondSource = mockTarget.classElement.source.fullName;
        throw InvalidMockitoAnnotationException(
            'Mockito cannot generate two mocks with the same name: $name (for '
            '${classNamesToMock[name].name} declared in $firstSource, and for '
            '${mockTarget.classElement.name} declared in $secondSource); '
            '$uniqueNameSuggestion.');
      }
      classNamesToMock[name] = mockTarget.classElement;
    }

    classNamesToMock.forEach((name, element) {
      var conflictingClass = classesInEntryLib.firstWhere((c) => c.name == name,
          orElse: () => null);
      if (conflictingClass != null) {
        throw InvalidMockitoAnnotationException(
            'Mockito cannot generate a mock with a name which conflicts with '
            'another class declared in this library: ${conflictingClass.name}; '
            '$uniqueNameSuggestion.');
      }

      var preexistingMock = classesInEntryLib.firstWhere(
          (c) =>
              c.interfaces.map((type) => type.element).contains(element) &&
              _isMockClass(c.supertype),
          orElse: () => null);
      if (preexistingMock != null) {
        throw InvalidMockitoAnnotationException(
            'The GenerateMocks annotation contains a class which appears to '
            'already be mocked inline: ${preexistingMock.name}; '
            '$uniqueNameSuggestion.');
      }

      _checkMethodsToStubAreValid(element);
    });
  }

  /// Throws if any public instance methods of [classElement] are not valid
  /// stubbing candidates.
  ///
  /// A method is not valid for stubbing if:
  /// - It has a private type anywhere in its signature; Mockito cannot override
  ///   such a method.
  /// - It has a non-nullable type variable return type, for example `T m<T>()`.
  ///   Mockito cannot generate dummy return values for unknown types.
  void _checkMethodsToStubAreValid(ClassElement classElement) {
    var className = classElement.name;
    var unstubbableErrorMessages = classElement.methods
        .where((m) => !m.isPrivate && !m.isStatic)
        .expand((m) => _checkFunction(m.type, m))
        .toList();

    if (unstubbableErrorMessages.isNotEmpty) {
      var joinedMessages =
          unstubbableErrorMessages.map((m) => '    $m').join('\n');
      throw InvalidMockitoAnnotationException(
          'Mockito cannot generate a valid mock class which implements '
          "'$className' for the following reasons:\n$joinedMessages");
    }
  }

  /// Checks [function] for properties that would make it un-stubbable.
  ///
  /// Types are checked in the following positions:
  /// - return type
  /// - parameter types
  /// - bounds of type parameters
  /// - type arguments
  List<String> _checkFunction(
      analyzer.FunctionType function, Element enclosingElement) {
    var errorMessages = <String>[];
    var returnType = function.returnType;
    if (returnType is analyzer.InterfaceType) {
      if (returnType.element?.isPrivate ?? false) {
        errorMessages.add(
            '${enclosingElement.fullName} features a private return type, and '
            'cannot be stubbed.');
      }
      errorMessages.addAll(
          _checkTypeArguments(returnType.typeArguments, enclosingElement));
    } else if (returnType is analyzer.FunctionType) {
      errorMessages.addAll(_checkFunction(returnType, enclosingElement));
    } else if (returnType is analyzer.TypeParameterType) {
      if (function.returnType is analyzer.TypeParameterType &&
          _entryLib.typeSystem.isPotentiallyNonNullable(function.returnType)) {
        errorMessages
            .add('${enclosingElement.fullName} features a non-nullable unknown '
                'return type, and cannot be stubbed.');
      }
    }

    for (var parameter in function.parameters) {
      var parameterType = parameter.type;
      var parameterTypeElement = parameterType.element;
      if (parameterType is analyzer.InterfaceType) {
        if (parameterTypeElement?.isPrivate ?? false) {
          // Technically, we can expand the type in the mock to something like
          // `Object?`. However, until there is a decent use case, we will not
          // generate such a mock.
          errorMessages.add(
              '${enclosingElement.fullName} features a private parameter type, '
              "'${parameterTypeElement.name}', and cannot be stubbed.");
        }
        errorMessages.addAll(
            _checkTypeArguments(parameterType.typeArguments, enclosingElement));
      } else if (parameterType is analyzer.FunctionType) {
        errorMessages.addAll(_checkFunction(parameterType, enclosingElement));
      }
    }

    errorMessages
        .addAll(_checkTypeParameters(function.typeFormals, enclosingElement));
    errorMessages
        .addAll(_checkTypeArguments(function.typeArguments, enclosingElement));

    return errorMessages;
  }

  /// Checks the bounds of [typeParameters] for properties that would make the
  /// enclosing method un-stubbable.
  static List<String> _checkTypeParameters(
      List<TypeParameterElement> typeParameters, Element enclosingElement) {
    var errorMessages = <String>[];
    for (var element in typeParameters) {
      var typeParameter = element.bound;
      if (typeParameter == null) continue;
      if (typeParameter is analyzer.InterfaceType) {
        if (typeParameter.element?.isPrivate ?? false) {
          errorMessages.add(
              '${enclosingElement.fullName} features a private type parameter '
              'bound, and cannot be stubbed.');
        }
      }
    }
    return errorMessages;
  }

  /// Checks [typeArguments] for properties that would make the enclosing
  /// method un-stubbable.
  ///
  /// See [_checkMethodsToStubAreValid] for what properties make a function
  /// un-stubbable.
  List<String> _checkTypeArguments(
      List<analyzer.DartType> typeArguments, Element enclosingElement) {
    var errorMessages = <String>[];
    for (var typeArgument in typeArguments) {
      if (typeArgument is analyzer.InterfaceType) {
        if (typeArgument.element?.isPrivate ?? false) {
          errorMessages.add(
              '${enclosingElement.fullName} features a private type argument, '
              'and cannot be stubbed.');
        }
      } else if (typeArgument is analyzer.FunctionType) {
        errorMessages.addAll(_checkFunction(typeArgument, enclosingElement));
      }
    }
    return errorMessages;
  }

  /// Return whether [type] is the Mock class declared by mockito.
  bool _isMockClass(analyzer.InterfaceType type) =>
      type.element.name == 'Mock' &&
      type.element.source.fullName.endsWith('lib/src/mock.dart');
}

class _MockLibraryInfo {
  final bool sourceLibIsNonNullable;

  /// The type provider which applies to the source library.
  final TypeProvider typeProvider;

  /// The type system which applies to the source library.
  final TypeSystem typeSystem;

  /// Mock classes to be added to the generated library.
  final mockClasses = <Class>[];

  /// Fake classes to be added to the library.
  ///
  /// A fake class is only generated when it is needed for non-nullable return
  /// values.
  final fakeClasses = <Class>[];

  /// [ClassElement]s which are used in non-nullable return types, for which
  /// fake classes are added to the generated library.
  final fakedClassElements = <ClassElement>[];

  /// Build mock classes for [mockTargets].
  _MockLibraryInfo(Iterable<_MockTarget> mockTargets,
      {this.sourceLibIsNonNullable, this.typeProvider, this.typeSystem}) {
    for (final mockTarget in mockTargets) {
      mockClasses.add(_buildMockClass(mockTarget));
    }
  }

  bool _hasExplicitTypeArguments(analyzer.InterfaceType type) {
    if (type.typeArguments == null) return false;

    // If it appears that one type argument was given, then they all were. This
    // returns the wrong result when the type arguments given are all `dynamic`,
    // or are each equal to the bound of the corresponding type parameter. There
    // may not be a way to get around this.
    for (var i = 0; i < type.typeArguments.length; i++) {
      var typeArgument = type.typeArguments[i];
      var bound =
          type.element.typeParameters[i].bound ?? typeProvider.dynamicType;
      // If [type] was given to @GenerateMocks as a Type, and no explicit type
      // argument is given, [typeArgument] is `dynamic` (_not_ the bound, as one
      // might think). We determine that an explicit type argument was given if
      // it is not `dynamic`.
      //
      // If, on the other hand, [type] was given to @GenerateMock as a type
      // argument to `Of()`, and no type argument is given, [typeArgument] is
      // the bound of the corresponding type paramter (dynamic or otherwise). We
      // determine that an explicit type argument was given if [typeArgument] is
      // is not [bound].
      if (!typeArgument.isDynamic && typeArgument != bound) return true;
    }
    return false;
  }

  Class _buildMockClass(_MockTarget mockTarget) {
    final typeToMock = mockTarget.classType;
    final classToMock = mockTarget.classElement;
    final className = classToMock.name;

    return Class((cBuilder) {
      cBuilder
        ..name = mockTarget.mockName
        ..extend = refer('Mock', 'package:mockito/mockito.dart')
        ..docs.add('/// A class which mocks [$className].')
        ..docs.add('///')
        ..docs.add('/// See the documentation for Mockito\'s code generation '
            'for more information.');
      // For each type parameter on [classToMock], the Mock class needs a type
      // parameter with same type variables, and a mirrored type argument for
      // the "implements" clause.
      var typeArguments = <Reference>[];
      if (_hasExplicitTypeArguments(typeToMock)) {
        // [typeToMock] is a reference to a type with type arguments (for
        // example: `Foo<int>`). Generate a non-generic mock class which
        // implements the mock target with said type arguments. For example:
        // `class MockFoo extends Mock implements Foo<int> {}`
        for (var typeArgument in typeToMock.typeArguments) {
          typeArguments.add(refer(typeArgument.element.name));
        }
      } else if (classToMock.typeParameters != null) {
        // [typeToMock] is a simple reference to a generic type (for example:
        // `Foo`, a reference to `class Foo<T> {}`). Generate a generic mock
        // class which perfectly mirrors the type parameters on [typeToMock],
        // forwarding them to the "implements" clause.
        for (var typeParameter in classToMock.typeParameters) {
          cBuilder.types.add(_typeParameterReference(typeParameter));
          typeArguments.add(refer(typeParameter.name));
        }
      }
      cBuilder.implements.add(TypeReference((b) {
        b
          ..symbol = classToMock.name
          ..url = _typeImport(mockTarget.classType)
          ..types.addAll(typeArguments);
      }));
      if (!mockTarget.returnNullOnMissingStub) {
        cBuilder.constructors.add(_constructorWithThrowOnMissingStub);
      }

      // Only override members of a class declared in a library which uses the
      // non-nullable type system.
      if (!sourceLibIsNonNullable) {
        return;
      }
      for (final field in classToMock.fields) {
        if (field.isPrivate || field.isStatic) {
          continue;
        }
        final getter = field.getter;
        if (getter != null && _returnTypeIsNonNullable(getter)) {
          cBuilder.methods.add(
              Method((mBuilder) => _buildOverridingGetter(mBuilder, getter)));
        }
        final setter = field.setter;
        if (setter != null && _hasNonNullableParameter(setter)) {
          cBuilder.methods.add(
              Method((mBuilder) => _buildOverridingSetter(mBuilder, setter)));
        }
      }
      for (final method in classToMock.methods) {
        if (method.isPrivate || method.isStatic) {
          continue;
        }
        if (_returnTypeIsNonNullable(method) ||
            _hasNonNullableParameter(method)) {
          cBuilder.methods.add(Method((mBuilder) =>
              _buildOverridingMethod(mBuilder, method, className: className)));
        }
      }
    });
  }

  /// The default behavior of mocks is to return null for unstubbed methods. To
  /// use the new behavior of throwing an error, we must explicitly call
  /// `throwOnMissingStub`.
  Constructor get _constructorWithThrowOnMissingStub =>
      Constructor((cBuilder) => cBuilder.body =
          refer('throwOnMissingStub', 'package:mockito/mockito.dart')
              .call([refer('this').expression]).statement);

  bool _returnTypeIsNonNullable(ExecutableElement method) =>
      typeSystem.isPotentiallyNonNullable(method.returnType);

  // Returns whether [method] has at least one parameter whose type is
  // potentially non-nullable.
  //
  // A parameter whose type uses a type variable may be non-nullable on certain
  // instances. For example:
  //
  //     class C<T> {
  //       void m(T a) {}
  //     }
  //     final c1 = C<int?>(); // m's parameter's type is nullable.
  //     final c2 = C<int>(); // m's parameter's type is non-nullable.
  bool _hasNonNullableParameter(ExecutableElement method) =>
      method.parameters.any((p) => typeSystem.isPotentiallyNonNullable(p.type));

  /// Build a method which overrides [method], with all non-nullable
  /// parameter types widened to be nullable.
  ///
  /// This new method just calls `super.noSuchMethod`, optionally passing a
  /// return value for methods with a non-nullable return type.
  void _buildOverridingMethod(MethodBuilder builder, MethodElement method,
      {@required String className}) {
    var name = method.displayName;
    if (method.isOperator) name = 'operator$name';
    builder
      ..name = name
      ..returns = _typeReference(method.returnType);

    if (method.typeParameters != null) {
      builder.types.addAll(method.typeParameters.map(_typeParameterReference));
    }

    // These two variables store the arguments that will be passed to the
    // [Invocation] built for `noSuchMethod`.
    final invocationPositionalArgs = <Expression>[];
    final invocationNamedArgs = <Expression, Expression>{};

    for (final parameter in method.parameters) {
      if (parameter.isRequiredPositional) {
        builder.requiredParameters
            .add(_matchingParameter(parameter, forceNullable: true));
        invocationPositionalArgs.add(refer(parameter.displayName));
      } else if (parameter.isOptionalPositional) {
        builder.optionalParameters
            .add(_matchingParameter(parameter, forceNullable: true));
        invocationPositionalArgs.add(refer(parameter.displayName));
      } else if (parameter.isNamed) {
        builder.optionalParameters
            .add(_matchingParameter(parameter, forceNullable: true));
        invocationNamedArgs[refer('#${parameter.displayName}')] =
            refer(parameter.displayName);
      }
    }

    if (_returnTypeIsNonNullable(method) &&
        method.returnType is analyzer.TypeParameterType) {}

    final invocation = refer('Invocation').property('method').call([
      refer('#${method.displayName}'),
      literalList(invocationPositionalArgs),
      if (invocationNamedArgs.isNotEmpty) literalMap(invocationNamedArgs),
    ]);
    final noSuchMethodArgs = <Expression>[invocation];
    if (_returnTypeIsNonNullable(method)) {
      final dummyReturnValue = _dummyValue(method.returnType);
      noSuchMethodArgs.add(dummyReturnValue);
    }
    final returnNoSuchMethod =
        refer('super').property('noSuchMethod').call(noSuchMethodArgs);

    builder.body = returnNoSuchMethod.code;
  }

  Expression _dummyValue(analyzer.DartType type) {
    if (type is analyzer.FunctionType) {
      return _dummyFunctionValue(type);
    }

    if (type is! analyzer.InterfaceType) {
      // TODO(srawlins): This case is not known.
      return literalNull;
    }

    var interfaceType = type as analyzer.InterfaceType;
    var typeArguments = interfaceType.typeArguments;
    if (interfaceType.isDartCoreBool) {
      return literalFalse;
    } else if (interfaceType.isDartCoreDouble) {
      return literalNum(0.0);
    } else if (interfaceType.isDartAsyncFuture ||
        interfaceType.isDartAsyncFutureOr) {
      var typeArgument = typeArguments.first;
      return refer('Future')
          .property('value')
          .call([_dummyValue(typeArgument)]);
    } else if (interfaceType.isDartCoreInt) {
      return literalNum(0);
    } else if (interfaceType.isDartCoreIterable) {
      return literalList([]);
    } else if (interfaceType.isDartCoreList) {
      assert(typeArguments.length == 1);
      var elementType = _typeReference(typeArguments[0]);
      return literalList([], elementType);
    } else if (interfaceType.isDartCoreMap) {
      assert(typeArguments.length == 2);
      var keyType = _typeReference(typeArguments[0]);
      var valueType = _typeReference(typeArguments[1]);
      return literalMap({}, keyType, valueType);
    } else if (interfaceType.isDartCoreNum) {
      return literalNum(0);
    } else if (interfaceType.isDartCoreSet) {
      assert(typeArguments.length == 1);
      var elementType = _typeReference(typeArguments[0]);
      return literalSet({}, elementType);
    } else if (interfaceType.element?.declaration ==
        typeProvider.streamElement) {
      assert(typeArguments.length == 1);
      var elementType = _typeReference(typeArguments[0]);
      return TypeReference((b) {
        b
          ..symbol = 'Stream'
          ..types.add(elementType);
      }).property('empty').call([]);
    } else if (interfaceType.isDartCoreString) {
      return literalString('');
    }

    // This class is unknown; we must likely generate a fake class, and return
    // an instance here.
    return _dummyValueImplementing(type as analyzer.InterfaceType);
  }

  Expression _dummyFunctionValue(analyzer.FunctionType type) {
    return Method((b) {
      // The positional parameters in a FunctionType have no names. This
      // counter lets us create unique dummy names.
      var counter = 0;
      for (final parameter in type.parameters) {
        if (parameter.isRequiredPositional) {
          b.requiredParameters
              .add(_matchingParameter(parameter, defaultName: '__p$counter'));
          counter++;
        } else if (parameter.isOptionalPositional) {
          b.optionalParameters
              .add(_matchingParameter(parameter, defaultName: '__p$counter'));
          counter++;
        } else if (parameter.isNamed) {
          b.optionalParameters.add(_matchingParameter(parameter));
        }
      }
      if (type.returnType.isVoid) {
        b.body = Code('');
      } else {
        b.body = _dummyValue(type.returnType).code;
      }
    }).closure;
  }

  Expression _dummyValueImplementing(analyzer.InterfaceType dartType) {
    // For each type parameter on [dartType], the Mock class needs a type
    // parameter with same type variables, and a mirrored type argument for the
    // "implements" clause.
    var typeParameters = <Reference>[];
    var elementToFake = dartType.element;
    if (elementToFake.isEnum) {
      return _typeReference(dartType).property(
          elementToFake.fields.firstWhere((f) => f.isEnumConstant).name);
    } else {
      // There is a potential for these names to collide. If one mock class
      // requires a fake for a certain Foo, and another mock class requires a
      // fake for a different Foo, they will collide.
      var fakeName = '_Fake${elementToFake.name}';
      // Only make one fake class for each class that needs to be faked.
      if (!fakedClassElements.contains(elementToFake)) {
        fakeClasses.add(Class((cBuilder) {
          cBuilder
            ..name = fakeName
            ..extend = refer('Fake', 'package:mockito/mockito.dart');
          if (elementToFake.typeParameters != null) {
            for (var typeParameter in elementToFake.typeParameters) {
              cBuilder.types.add(_typeParameterReference(typeParameter));
              typeParameters.add(refer(typeParameter.name));
            }
          }
          cBuilder.implements.add(TypeReference((b) {
            b
              ..symbol = elementToFake.name
              ..url = _typeImport(dartType)
              ..types.addAll(typeParameters);
          }));
        }));
        fakedClassElements.add(elementToFake);
      }
      var typeArguments = dartType.typeArguments;
      return TypeReference((b) {
        b
          ..symbol = fakeName
          ..types.addAll(typeArguments.map(_typeReference));
      }).newInstance([]);
    }
  }

  /// Returns a [Parameter] which matches [parameter].
  ///
  /// If [parameter] is unnamed (like a positional parameter in a function
  /// type), a [defaultName] can be passed as the name.
  ///
  /// If the type needs to be nullable, rather than matching the nullability of
  /// [parameter], use [forceNullable].
  Parameter _matchingParameter(ParameterElement parameter,
      {String defaultName, bool forceNullable = false}) {
    var name = parameter.name?.isEmpty ?? false ? defaultName : parameter.name;
    return Parameter((pBuilder) {
      pBuilder
        ..name = name
        ..type = _typeReference(parameter.type, forceNullable: forceNullable);
      if (parameter.isNamed) pBuilder.named = true;
      if (parameter.defaultValueCode != null) {
        try {
          pBuilder.defaultTo =
              _expressionFromDartObject(parameter.computeConstantValue()).code;
        } on _ReviveException catch (e) {
          final method = parameter.enclosingElement;
          final clazz = method.enclosingElement;
          throw InvalidMockitoAnnotationException(
              'Mockito cannot generate a valid stub for method '
              "'${clazz.displayName}.${method.displayName}'; parameter "
              "'${parameter.displayName}' causes a problem: ${e.message}");
        }
      }
    });
  }

  /// Creates a code_builder [Expression] from [object], a constant object from
  /// analyzer.
  ///
  /// This is very similar to Angular's revive code, in
  /// angular_compiler/analyzer/di/injector.dart.
  Expression _expressionFromDartObject(DartObject object) {
    final constant = ConstantReader(object);
    if (constant.isNull) {
      return literalNull;
    } else if (constant.isBool) {
      return literalBool(constant.boolValue);
    } else if (constant.isDouble) {
      return literalNum(constant.doubleValue);
    } else if (constant.isInt) {
      return literalNum(constant.intValue);
    } else if (constant.isString) {
      return literalString(constant.stringValue, raw: true);
    } else if (constant.isList) {
      return literalConstList([
        for (var element in constant.listValue)
          _expressionFromDartObject(element)
      ]);
    } else if (constant.isMap) {
      return literalConstMap({
        for (var pair in constant.mapValue.entries)
          _expressionFromDartObject(pair.key):
              _expressionFromDartObject(pair.value)
      });
    } else if (constant.isSet) {
      return literalConstSet({
        for (var element in constant.setValue)
          _expressionFromDartObject(element)
      });
    } else if (constant.isType) {
      // TODO(srawlins): It seems like this might be revivable, but Angular
      // does not revive Types; we should investigate this if users request it.
      var type = object.toTypeValue();
      var typeStr = type.getDisplayString(withNullability: false);
      throw _ReviveException('default value is a Type: $typeStr.');
    } else {
      // If [constant] is not null, a literal, or a type, then it must be an
      // object constructed with `const`. Revive it.
      var revivable = constant.revive();
      if (revivable.isPrivate) {
        final privateReference = revivable.accessor?.isNotEmpty == true
            ? '${revivable.source}::${revivable.accessor}'
            : '${revivable.source}';
        throw _ReviveException(
            'default value has a private type: $privateReference.');
      }
      if (revivable.source.fragment.isEmpty) {
        // We can create this invocation by referring to a const field.
        return refer(revivable.accessor, _typeImport(object.type));
      }

      final name = revivable.source.fragment;
      final positionalArgs = [
        for (var argument in revivable.positionalArguments)
          _expressionFromDartObject(argument)
      ];
      final namedArgs = {
        for (var pair in revivable.namedArguments.entries)
          pair.key: _expressionFromDartObject(pair.value)
      };
      final type = refer(name, _typeImport(object.type));
      if (revivable.accessor.isNotEmpty) {
        return type.constInstanceNamed(
          revivable.accessor,
          positionalArgs,
          namedArgs,
          // No type arguments. See
          // https://github.com/dart-lang/source_gen/issues/478.
        );
      }
      return type.constInstance(positionalArgs, namedArgs);
    }
  }

  /// Build a getter which overrides [getter].
  ///
  /// This new method just calls `super.noSuchMethod`, optionally passing a
  /// return value for non-nullable getters.
  void _buildOverridingGetter(
      MethodBuilder builder, PropertyAccessorElement getter) {
    builder
      ..name = getter.displayName
      ..type = MethodType.getter
      ..returns = _typeReference(getter.returnType);

    final invocation = refer('Invocation').property('getter').call([
      refer('#${getter.displayName}'),
    ]);
    final noSuchMethodArgs = [invocation, _dummyValue(getter.returnType)];
    final returnNoSuchMethod =
        refer('super').property('noSuchMethod').call(noSuchMethodArgs);

    builder.body = returnNoSuchMethod.code;
  }

  /// Build a setter which overrides [setter], widening the single parameter
  /// type to be nullable if it is non-nullable.
  ///
  /// This new setter just calls `super.noSuchMethod`.
  void _buildOverridingSetter(
      MethodBuilder builder, PropertyAccessorElement setter) {
    builder
      ..name = setter.displayName
      ..type = MethodType.setter;

    final invocationPositionalArgs = <Expression>[];
    // There should only be one required positional parameter. Should we assert
    // on that? Leave it alone?
    for (final parameter in setter.parameters) {
      if (parameter.isRequiredPositional) {
        builder.requiredParameters.add(Parameter((pBuilder) => pBuilder
          ..name = parameter.displayName
          ..type = _typeReference(parameter.type, forceNullable: true)));
        invocationPositionalArgs.add(refer(parameter.displayName));
      }
    }

    final invocation = refer('Invocation').property('setter').call([
      refer('#${setter.displayName}'),
      literalList(invocationPositionalArgs),
    ]);
    final returnNoSuchMethod =
        refer('super').property('noSuchMethod').call([invocation]);

    builder.body = returnNoSuchMethod.code;
  }

  /// Create a reference for [typeParameter], properly referencing all types
  /// in bounds.
  TypeReference _typeParameterReference(TypeParameterElement typeParameter) {
    return TypeReference((b) {
      b.symbol = typeParameter.name;
      if (typeParameter.bound != null) {
        b.bound = _typeReference(typeParameter.bound);
      }
    });
  }

  /// Create a reference for [type], properly referencing all attached types.
  ///
  /// If the type needs to be nullable, rather than matching the nullability of
  /// [type], use [forceNullable].
  ///
  /// This creates proper references for:
  /// * InterfaceTypes (classes, generic classes),
  /// * FunctionType parameters (like `void callback(int i)`),
  /// * type aliases (typedefs), both new- and old-style,
  /// * enums,
  /// * type variables.
  // TODO(srawlins): Contribute this back to a common location, like
  // package:source_gen?
  Reference _typeReference(analyzer.DartType type,
      {bool forceNullable = false}) {
    if (type is analyzer.InterfaceType) {
      return TypeReference((b) {
        b
          ..symbol = type.element.name
          ..isNullable = forceNullable || typeSystem.isPotentiallyNullable(type)
          ..url = _typeImport(type)
          ..types.addAll(type.typeArguments.map(_typeReference));
      });
    } else if (type is analyzer.FunctionType) {
      var element = type.element;
      if (element == null) {
        // [type] represents a FunctionTypedFormalParameter.
        return FunctionType((b) {
          b
            ..isNullable =
                forceNullable || typeSystem.isPotentiallyNullable(type)
            ..returnType = _typeReference(type.returnType)
            ..requiredParameters
                .addAll(type.normalParameterTypes.map(_typeReference))
            ..optionalParameters
                .addAll(type.optionalParameterTypes.map(_typeReference));
          for (var parameter in type.namedParameterTypes.entries) {
            b.namedParameters[parameter.key] = _typeReference(parameter.value);
          }
          if (type.typeFormals != null) {
            b.types.addAll(type.typeFormals.map(_typeParameterReference));
          }
        });
      }
      return TypeReference((b) {
        Element typedef;
        if (element is FunctionTypeAliasElement) {
          typedef = element;
        } else {
          typedef = element.enclosingElement;
        }

        b
          ..symbol = typedef.name
          ..url = _typeImport(type)
          ..isNullable = forceNullable || typeSystem.isNullable(type);
        for (var typeArgument in type.typeArguments) {
          b.types.add(_typeReference(typeArgument));
        }
      });
    } else if (type is analyzer.TypeParameterType) {
      return TypeReference((b) {
        b
          ..symbol = type.element.name
          ..isNullable = forceNullable || typeSystem.isNullable(type);
      });
    } else {
      return refer(
        type.getDisplayString(withNullability: false),
        _typeImport(type),
      );
    }
  }

  /// Returns the import URL for [type].
  ///
  /// For some types, like `dynamic` and type variables, this may return null.
  String _typeImport(analyzer.DartType type) {
    // For type variables, no import needed.
    if (type is analyzer.TypeParameterType) return null;

    var library = type.element?.library;

    // For types like `dynamic`, return null; no import needed.
    if (library == null) return null;
    // TODO(srawlins): See what other code generators do here to guarantee sane
    // URIs.
    return library.source.uri.toString();
  }
}

/// An exception thrown when reviving a potentially deep value in a constant.
///
/// This exception should always be caught within this library. An
/// [InvalidMockitoAnnotationException] can be presented to the user after
/// catching this exception.
class _ReviveException implements Exception {
  final String message;

  _ReviveException(this.message);
}

/// An exception which is thrown when Mockito encounters an invalid annotation.
class InvalidMockitoAnnotationException implements Exception {
  final String message;

  InvalidMockitoAnnotationException(this.message);

  @override
  String toString() => 'Invalid @GenerateMocks annotation: $message';
}

/// A [MockBuilder] instance for use by `build.yaml`.
Builder buildMocks(BuilderOptions options) => MockBuilder();

extension on Element {
  /// Returns the "full name" of a class or method element.
  String get fullName {
    if (this is ClassElement) {
      return "The class '$name'";
    } else if (this is MethodElement) {
      var className = enclosingElement.name;
      return "The method '$className.$name'";
    } else {
      return 'unknown element';
    }
  }
}
