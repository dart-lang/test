// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart' hide FunctionType, RecordType;
import 'package:code_builder/code_builder.dart'
    as cb
    show FunctionType, RecordType;
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart' as source_gen show LibraryBuilder;
import 'package:source_gen/source_gen.dart' hide LibraryBuilder;

import 'annotation.dart';

Builder checksBuilder(BuilderOptions? _) => source_gen.LibraryBuilder(
  const ChecksGenerator(),
  generatedExtension: '.checks.dart',
);

final class ChecksGenerator extends GeneratorForAnnotation<CheckExtensions> {
  const ChecksGenerator();

  @override
  Future<String> generateForAnnotatedDirective(
    ElementDirective directive,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final basename = p.url.basenameWithoutExtension(buildStep.inputId.path);
    final expectedImport = '$basename.checks.dart';

    if (directive
        case LibraryImport(:final DirectiveUriWithRelativeUri uri) ||
            LibraryExport(:final DirectiveUriWithRelativeUri uri)
        when uri.relativeUriString == expectedImport) {
      // Annotation is on the correct import or export
    } else {
      throw InvalidGenerationSourceError(
        'must annotate an import or export of $expectedImport',
      );
    }
    final typesField = annotation.read('types');
    if (!typesField.isList) {
      throw InvalidGenerationSourceError(
        'Failed to resolve the specified types. '
        'Check for a missing build dependency.',
      );
    }
    final types = typesField.listValue;
    final extensions = await Future.wait([
      for (final object in types)
        _createExtension(
          directive.libraryFragment.importedLibraries,
          object,
          buildStep.resolver,
          buildStep.inputId.path,
        ),
    ]);
    final library = Library(
      (b) => b
        ..body.addAll(extensions)
        ..directives.add(
          Directive(
            (b) => b
              ..type = DirectiveType.import
              ..url = 'package:checks/checks.dart',
          ),
        ),
    );
    final emitter = DartEmitter.scoped(
      useNullSafetySyntax: true,
      orderDirectives: true,
    );
    return library.accept(emitter).toString();
  }

  @override
  dynamic generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final basename = p.url.basenameWithoutExtension(buildStep.inputId.path);
    throw InvalidGenerationSourceError(
      'must annotate an import or export of $basename.checks.dart',
      element: element,
    );
  }

  Future<Extension> _createExtension(
    List<LibraryElement> imports,
    DartObject dartObject,
    Resolver resolver,
    String entryAssetPath,
  ) async {
    final type = dartObject.toTypeValue();
    if (type is! InterfaceType) {
      throw InvalidGenerationSourceError(
        'Only interface types may be used for checks extensions: $type',
      );
    }
    final element = type.element;
    Future<String?> importFor(Element element) =>
        _findImportFor(imports, element, resolver, entryAssetPath);
    final import = await importFor(element);
    // The extension is on the raw type, so field types are read from the type
    // instantiated to bounds to match the static type of `v.field`.
    final rawType = element.library.typeSystem.instantiateInterfaceToBounds(
      element: element,
      nullabilitySuffix: NullabilitySuffix.none,
    );
    final hasGetters = await Future.wait([
      for (final field in element.fields)
        if (_isCheckableField(field))
          if (rawType.getGetter(field.name!) case final getter?)
            _createHasGetter(field.name!, getter.returnType, importFor),
    ]);
    return Extension(
      (b) => b
        ..name = '${element.displayName}Checks'
        ..on = TypeReference(
          (b) => b
            ..symbol = 'Subject'
            ..url = 'package:checks/context.dart'
            ..types.add(refer(element.displayName, import)),
        )
        ..methods.addAll(hasGetters),
    );
  }

  bool _isCheckableField(FieldElement field) =>
      field.name != 'hashCode' && !field.isStatic;

  Future<Method> _createHasGetter(
    String name,
    DartType type,
    Future<String?> Function(Element) importFor,
  ) async {
    final typeReference = await _typeReference(type, importFor);
    return Method(
      (b) => b
        ..name = name
        ..type = MethodType.getter
        ..returns = TypeReference(
          (b) => b
            ..symbol = 'Subject'
            ..url = 'package:checks/context.dart'
            ..types.add(typeReference),
        )
        ..lambda = true
        ..body = refer('has').call([
          Method(
            (b) => b
              ..lambda = true
              ..requiredParameters.add(Parameter((b) => b..name = 'v'))
              ..body = refer('v').property(name).code,
          ).closure,
          literalString(name),
        ]).code,
    );
  }

  /// A reference to [type] which imports the libraries for every element
  /// referenced within [type].
  ///
  /// The only type parameters which may be referenced within [type] are those
  /// of generic function types within [type], which are in scope where they
  /// are referenced.
  static Future<Reference> _typeReference(
    DartType type,
    Future<String?> Function(Element) importFor,
  ) async {
    final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
    return switch (type) {
      DynamicType() => refer('dynamic'),
      VoidType() => refer('void'),
      NeverType() => TypeReference(
        (b) => b
          ..symbol = 'Never'
          ..url = 'dart:core'
          ..isNullable = isNullable,
      ),
      InterfaceType() => await _interfaceTypeReference(type, importFor),
      TypeParameterType(:final element) => TypeReference(
        (b) => b
          ..symbol = element.name
          ..isNullable = isNullable,
      ),
      FunctionType() => await _functionTypeReference(type, importFor),
      RecordType() => await _recordTypeReference(type, importFor),
      _ => throw InvalidGenerationSourceError(
        'Failed to resolve the type $type. '
        'Check for a missing build dependency.',
      ),
    };
  }

  static Future<Reference> _interfaceTypeReference(
    InterfaceType type,
    Future<String?> Function(Element) importFor,
  ) async {
    final import = await importFor(type.element);
    final types = [
      for (final typeArgument in type.typeArguments)
        await _typeReference(typeArgument, importFor),
    ];
    return TypeReference(
      (b) => b
        ..symbol = type.element.name
        ..url = import
        ..types.addAll(types)
        ..isNullable = type.nullabilitySuffix == NullabilitySuffix.question,
    );
  }

  static Future<Reference> _functionTypeReference(
    FunctionType type,
    Future<String?> Function(Element) importFor,
  ) async {
    final typeParameters = <Reference>[];
    for (final typeParameter in type.typeParameters) {
      final bound = typeParameter.bound;
      final boundReference = bound == null
          ? null
          : await _typeReference(bound, importFor);
      typeParameters.add(
        TypeReference(
          (b) => b
            ..symbol = typeParameter.name
            ..bound = boundReference,
        ),
      );
    }
    final returnType = await _typeReference(type.returnType, importFor);
    final requiredParameters = <Reference>[];
    final optionalParameters = <Reference>[];
    final namedParameters = <String, Reference>{};
    final namedRequiredParameters = <String, Reference>{};
    for (final parameter in type.formalParameters) {
      final parameterType = await _typeReference(parameter.type, importFor);
      if (parameter.isRequiredPositional) {
        requiredParameters.add(parameterType);
      } else if (parameter.isOptionalPositional) {
        optionalParameters.add(parameterType);
      } else if (parameter.isRequiredNamed) {
        namedRequiredParameters[parameter.name!] = parameterType;
      } else {
        namedParameters[parameter.name!] = parameterType;
      }
    }
    return cb.FunctionType(
      (b) => b
        ..returnType = returnType
        ..types.addAll(typeParameters)
        ..requiredParameters.addAll(requiredParameters)
        ..optionalParameters.addAll(optionalParameters)
        ..namedParameters.addAll(namedParameters)
        ..namedRequiredParameters.addAll(namedRequiredParameters)
        ..isNullable = type.nullabilitySuffix == NullabilitySuffix.question,
    );
  }

  static Future<Reference> _recordTypeReference(
    RecordType type,
    Future<String?> Function(Element) importFor,
  ) async {
    final positionalFieldTypes = [
      for (final field in type.positionalFields)
        await _typeReference(field.type, importFor),
    ];
    final namedFieldTypes = {
      for (final field in type.namedFields)
        field.name: await _typeReference(field.type, importFor),
    };
    return cb.RecordType(
      (b) => b
        ..positionalFieldTypes.addAll(positionalFieldTypes)
        ..namedFieldTypes.addAll(namedFieldTypes)
        ..isNullable = type.nullabilitySuffix == NullabilitySuffix.question,
    );
  }

  static Future<String?> _findImportFor(
    Iterable<LibraryElement> imports,
    Element element,
    Resolver resolver,
    String entryAssetPath,
  ) async {
    final elementLibrary = element.library!;
    if (elementLibrary.isInSdk && !elementLibrary.name!.startsWith('dart._')) {
      // For public SDK libraries, just use the source URI.
      return elementLibrary.uri.toString();
    }
    final elementName = element.name;
    if (elementName == null) {
      return elementLibrary.uri.toString();
    }
    final exported = imports.firstWhereOrNull(
      (l) => l.exportNamespace.get2(elementName) == element,
    );
    final exportingLibrary = exported ?? elementLibrary;

    try {
      final typeAssetId = await resolver.assetIdForElement(exportingLibrary);

      if (typeAssetId.path.startsWith('lib/')) {
        return typeAssetId.uri.toString();
      } else {
        return p.url.relative(
          typeAssetId.path,
          from: p.dirname(entryAssetPath),
        );
      }
    } on UnresolvableAssetException {
      // Asset may be in a summary.
      return exportingLibrary.uri.toString();
    }
  }
}
