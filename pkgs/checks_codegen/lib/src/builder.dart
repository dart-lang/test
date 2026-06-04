// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
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
    final import = await _findImportFor(
      imports,
      element,
      resolver,
      entryAssetPath,
    );
    final hasGetters = await Future.wait([
      for (final field in element.fields)
        if (_isCheckableField(field))
          _createHasGetter(imports, field, resolver, entryAssetPath),
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
    List<LibraryElement> imports,
    FieldElement field,
    Resolver resolver,
    String entryAssetPath,
  ) async {
    final type = field.type;
    if (type is! InterfaceType) {
      throw InvalidGenerationSourceError(
        'Only interface types may be used for checks extensions:: $type',
      );
    }
    final import = await _findImportFor(
      imports,
      type.element,
      resolver,
      entryAssetPath,
    );
    final name = field.name!;
    return Method(
      (b) => b
        ..name = name
        ..type = MethodType.getter
        ..returns = TypeReference(
          (b) => b
            ..symbol = 'Subject'
            ..url = 'package:checks/context.dart'
            ..types.add(refer(field.type.getDisplayString(), import)),
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
