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
    final targets = [
      for (final object in typesField.listValue) _CheckTarget(object),
    ];
    final referencedElements = <InterfaceElement>{};
    for (final target in targets) {
      referencedElements.add(target.element);
      for (final (field: _, :type) in target.fields) {
        _collectElements(type, referencedElements);
      }
    }
    final importUris = await _resolveImports(
      directive.libraryFragment,
      referencedElements,
      buildStep.resolver,
      buildStep.inputId.path,
    );
    final library = Library(
      (b) => b
        ..body.addAll([
          for (final target in targets) _createExtension(target, importUris),
        ])
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

  Extension _createExtension(
    _CheckTarget target,
    Map<InterfaceElement, String> importUris,
  ) {
    final element = target.element;
    return Extension(
      (b) => b
        ..name = '${element.displayName}Checks'
        ..on = TypeReference(
          (b) => b
            ..symbol = 'Subject'
            ..url = 'package:checks/context.dart'
            ..types.add(refer(element.displayName, importUris[element])),
        )
        ..methods.addAll([
          for (final (:field, :type) in target.fields)
            _createHasGetter(field, type, importUris),
        ]),
    );
  }

  Method _createHasGetter(
    FieldElement field,
    DartType type,
    Map<InterfaceElement, String> importUris,
  ) {
    final name = field.name!;
    final Reference typeReference;
    try {
      typeReference = _typeReference(type, importUris);
    } on _UnresolvedType {
      throw InvalidGenerationSourceError(
        'Failed to resolve the type of '
        '`${field.enclosingElement.displayName}.$name`. '
        'Check for a missing build dependency.',
        element: field,
      );
    }
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
        ..body = refer('has2').call([
          literalString(name),
          Method(
            (b) => b
              ..lambda = true
              ..requiredParameters.add(Parameter((b) => b..name = 'v'))
              ..body = refer('v').property(name).code,
          ).closure,
        ]).code,
    );
  }

  /// Adds the element of every interface type within [type] to [elements].
  ///
  /// Must visit every interface type that [_typeReference] references, so
  /// that an import is resolved for each of them.
  static void _collectElements(DartType type, Set<InterfaceElement> elements) {
    switch (type) {
      case InterfaceType(:final element, :final typeArguments):
        elements.add(element);
        for (final typeArgument in typeArguments) {
          _collectElements(typeArgument, elements);
        }
      case FunctionType():
        for (final typeParameter in type.typeParameters) {
          if (typeParameter.bound case final bound?) {
            _collectElements(bound, elements);
          }
        }
        _collectElements(type.returnType, elements);
        for (final parameter in type.formalParameters) {
          _collectElements(parameter.type, elements);
        }
      case RecordType(:final positionalFields, :final namedFields):
        for (final field in positionalFields) {
          _collectElements(field.type, elements);
        }
        for (final field in namedFields) {
          _collectElements(field.type, elements);
        }
    }
  }

  /// A reference to [type] which imports the libraries for every element
  /// referenced within [type].
  ///
  /// The only type parameters which may be referenced within [type] are those
  /// of generic function types within [type], which are in scope where they
  /// are referenced.
  ///
  /// Throws an [_UnresolvedType] if any type within [type] failed to resolve.
  static Reference _typeReference(
    DartType type,
    Map<InterfaceElement, String> importUris,
  ) {
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
      InterfaceType() => _interfaceTypeReference(type, importUris),
      TypeParameterType(:final element) => TypeReference(
        (b) => b
          ..symbol = element.name
          ..isNullable = isNullable,
      ),
      FunctionType() => _functionTypeReference(type, importUris),
      RecordType() => _recordTypeReference(type, importUris),
      _ => throw const _UnresolvedType(),
    };
  }

  static Reference _interfaceTypeReference(
    InterfaceType type,
    Map<InterfaceElement, String> importUris,
  ) => TypeReference(
    (b) => b
      ..symbol = type.element.name
      ..url = importUris[type.element]!
      ..types.addAll([
        for (final typeArgument in type.typeArguments)
          _typeReference(typeArgument, importUris),
      ])
      ..isNullable = type.nullabilitySuffix == NullabilitySuffix.question,
  );

  static Reference _functionTypeReference(
    FunctionType type,
    Map<InterfaceElement, String> importUris,
  ) {
    final typeParameters = [
      for (final typeParameter in type.typeParameters)
        TypeReference(
          (b) => b
            ..symbol = typeParameter.name
            ..bound = switch (typeParameter.bound) {
              final bound? => _typeReference(bound, importUris),
              null => null,
            },
        ),
    ];
    final returnType = _typeReference(type.returnType, importUris);
    final requiredParameters = <Reference>[];
    final optionalParameters = <Reference>[];
    final namedParameters = <String, Reference>{};
    final namedRequiredParameters = <String, Reference>{};
    for (final parameter in type.formalParameters) {
      final parameterType = _typeReference(parameter.type, importUris);
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

  static Reference _recordTypeReference(
    RecordType type,
    Map<InterfaceElement, String> importUris,
  ) => cb.RecordType(
    (b) => b
      ..positionalFieldTypes.addAll([
        for (final field in type.positionalFields)
          _typeReference(field.type, importUris),
      ])
      ..namedFieldTypes.addAll({
        for (final field in type.namedFields)
          field.name: _typeReference(field.type, importUris),
      })
      ..isNullable = type.nullabilitySuffix == NullabilitySuffix.question,
  );

  /// The URI to import for each of [elements].
  ///
  /// Elements declared in public SDK libraries are imported from their
  /// declaring library. Other elements are imported from the first library
  /// which exports them, searching in order:
  ///
  /// 1. The imports of [testLibrary].
  /// 2. The imports of the libraries which declare [elements].
  /// 3. For elements declared in private SDK libraries, the public SDK
  ///    libraries, see [_findPublicSdkLibraries].
  ///
  /// Within the first two groups libraries outside of `src/` are searched
  /// first.
  ///
  /// If no library exports an element it is imported from its declaring
  /// library, which may be under `src/`. It is an error if that library is a
  /// private SDK library, since it cannot be imported.
  static Future<Map<InterfaceElement, String>> _resolveImports(
    LibraryFragment testLibrary,
    Set<InterfaceElement> elements,
    Resolver resolver,
    String entryAssetPath,
  ) async {
    final declaringLibraries = {
      for (final element in elements) element.library,
    };
    final candidates = [
      ...testLibrary.importedLibraries
          .whereNot(_isPrivateSdkLibrary)
          .sorted(_compareLibraries),
      ...{
        for (final library in declaringLibraries)
          for (final fragment in library.fragments)
            ...fragment.importedLibraries,
      }.whereNot(_isPrivateSdkLibrary).sorted(_compareLibraries),
    ];
    List<LibraryElement>? publicSdkLibraries;
    final importUris = <InterfaceElement, String>{};
    for (final element in elements) {
      final declaringLibrary = element.library;
      if (_isPublicSdkLibrary(declaringLibrary)) {
        importUris[element] = declaringLibrary.uri.toString();
        continue;
      }
      var exportingLibrary = _findExportOf(candidates, element);
      if (exportingLibrary == null && _isPrivateSdkLibrary(declaringLibrary)) {
        publicSdkLibraries ??= await _findPublicSdkLibraries([
          testLibrary.element,
          ...declaringLibraries,
        ], resolver);
        exportingLibrary =
            _findExportOf(publicSdkLibraries, element) ??
            (throw InvalidGenerationSourceError(
              'Cannot import `${element.displayName}`. It is declared in '
              '${declaringLibrary.uri} and not exported by any public '
              'library.',
            ));
      }
      importUris[element] = await _importUriFor(
        exportingLibrary ?? declaringLibrary,
        resolver,
        entryAssetPath,
      );
    }
    return importUris;
  }

  /// Returns the first library in [candidates] which exports [element], if
  /// any.
  static LibraryElement? _findExportOf(
    Iterable<LibraryElement> candidates,
    InterfaceElement element,
  ) {
    final name = element.name;
    if (name == null) return null;
    return candidates.firstWhereOrNull(
      (library) => library.exportNamespace.get2(name) == element,
    );
  }

  /// The public SDK libraries to search for elements declared in private SDK
  /// libraries.
  ///
  /// Libraries reachable through imports and exports from [roots] come first,
  /// since they are available on the platform the program targets. Some
  /// elements are exported by multiple public SDK libraries for different
  /// platforms, for instance `HttpStatus` from both `dart:io` and `dart:html`.
  /// The remaining public SDK libraries known to [resolver] follow. Each group
  /// is sorted by URI.
  static Future<List<LibraryElement>> _findPublicSdkLibraries(
    Iterable<LibraryElement> roots,
    Resolver resolver,
  ) async {
    final reachable = <LibraryElement>{};
    final toVisit = [...roots];
    while (toVisit.isNotEmpty) {
      final library = toVisit.removeLast();
      if (!reachable.add(library)) continue;
      for (final fragment in library.fragments) {
        toVisit.addAll(fragment.importedLibraries);
      }
      toVisit.addAll(library.exportedLibraries);
    }
    final allLibraries = await resolver.libraries.toList();
    String uri(LibraryElement library) => library.uri.toString();
    return [
      ...reachable.where(_isPublicSdkLibrary).sortedBy(uri),
      ...allLibraries
          .where(_isPublicSdkLibrary)
          .whereNot(reachable.contains)
          .sortedBy(uri),
    ];
  }

  /// The URI to use in the generated library to import [library].
  static Future<String> _importUriFor(
    LibraryElement library,
    Resolver resolver,
    String entryAssetPath,
  ) async {
    if (library.isInSdk) return library.uri.toString();
    try {
      final assetId = await resolver.assetIdForElement(library);
      if (assetId.path.startsWith('lib/')) {
        return assetId.uri.toString();
      } else {
        return p.url.relative(assetId.path, from: p.dirname(entryAssetPath));
      }
    } on UnresolvableAssetException {
      // Asset may be in a summary.
      return library.uri.toString();
    }
  }

  static bool _isPrivateSdkLibrary(LibraryElement library) =>
      library.isInSdk && library.uri.path.startsWith('_');

  static bool _isPublicSdkLibrary(LibraryElement library) =>
      library.isInSdk && !library.uri.path.startsWith('_');

  /// Orders libraries by scheme, then libraries outside of `src/` first, then
  /// by path.
  static int _compareLibraries(LibraryElement a, LibraryElement b) {
    final schemeComparison = a.uri.scheme.compareTo(b.uri.scheme);
    if (schemeComparison != 0) return schemeComparison;
    final aIsSrc = a.uri.path.contains('/src/');
    final bIsSrc = b.uri.path.contains('/src/');
    if (aIsSrc != bIsSrc) return aIsSrc ? 1 : -1;
    return a.uri.path.compareTo(b.uri.path);
  }
}

/// A class to generate a checks extension for.
final class _CheckTarget {
  final InterfaceElement element;

  /// The fields to generate getters for, with their types.
  ///
  /// The extension is on the raw type, so field types are read from the type
  /// instantiated to bounds to match the static type of `v.field`.
  final List<({FieldElement field, DartType type})> fields;

  _CheckTarget._(this.element, this.fields);

  factory _CheckTarget(DartObject dartObject) {
    final type = dartObject.toTypeValue();
    if (type is! InterfaceType) {
      throw InvalidGenerationSourceError(
        'Only interface types may be used for checks extensions: $type',
      );
    }
    final element = type.element;
    if (element.isPrivate) {
      throw InvalidGenerationSourceError(
        'Private types cannot be used for checks extensions: '
        '`${element.displayName}`',
        element: element,
      );
    }
    final rawType = element.library.typeSystem.instantiateInterfaceToBounds(
      element: element,
      nullabilitySuffix: NullabilitySuffix.none,
    );
    return _CheckTarget._(element, [
      for (final field in element.fields)
        if (_isCheckableField(field))
          if (rawType.getGetter(field.name!) case final getter?
              when !_referencesPrivateType(getter.returnType))
            (field: field, type: getter.returnType),
    ]);
  }

  /// Whether [field] should get a `has` getter.
  ///
  /// Checks whether the field can be referenced on an instance of the class
  /// containing [field] from the generated library.
  static bool _isCheckableField(FieldElement field) =>
      field.name != 'hashCode' && !field.isStatic && !field.isPrivate;

  static bool _referencesPrivateType(DartType type) => switch (type) {
    InterfaceType(:final element, :final typeArguments) =>
      element.isPrivate || typeArguments.any(_referencesPrivateType),
    FunctionType(
      :final typeParameters,
      :final returnType,
      :final formalParameters,
    ) =>
      typeParameters.any(
            (p) => p.bound != null && _referencesPrivateType(p.bound!),
          ) ||
          _referencesPrivateType(returnType) ||
          formalParameters.any((p) => _referencesPrivateType(p.type)),
    RecordType(:final positionalFields, :final namedFields) =>
      positionalFields.any((f) => _referencesPrivateType(f.type)) ||
          namedFields.any((f) => _referencesPrivateType(f.type)),
    _ => false,
  };
}

/// Thrown by [ChecksGenerator._typeReference] when a type failed to resolve.
///
/// Caught where the field that has the type is known so that the reported
/// error can point to it.
final class _UnresolvedType implements Exception {
  const _UnresolvedType();
}
