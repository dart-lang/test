// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart' hide FunctionType;
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
    final compilationUnit = await buildStep.resolver.astNodeFor(
      directive.libraryFragment,
    ) as ast.CompilationUnit?;
    if (compilationUnit == null) {
      throw InvalidGenerationSourceError('Could not find AST for library.');
    }
    final typeNames = await _extractTypeNamesFromAst(
      compilationUnit,
      expectedImport,
    );

    if (typeNames.isEmpty) {
      throw InvalidGenerationSourceError(
        'Could not find @CheckExtensions annotation or it was empty.',
      );
    }

    final currentLibrary = directive.libraryFragment.element;
    final imports = directive.libraryFragment.importedLibraries;

    final targetElements = <Element>[];
    for (final name in typeNames) {
      final element = _findElementByName(currentLibrary, imports, name);
      if (element != null) {
        targetElements.add(element);
      } else {
        throw InvalidGenerationSourceError('Could not resolve type: $name');
      }
    }

    final extensions = await Future.wait([
      for (final element in targetElements)
        _createExtension(
          directive.libraryFragment.importedLibraries,
          element,
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
    Element element,
    Resolver resolver,
    String entryAssetPath,
  ) async {
    final import = await _findImportFor(
      imports,
      element,
      resolver,
      entryAssetPath,
    );
    final checkableProperties = _getCheckableProperties(element);
    final hasGetters = await Future.wait([
      for (final property in checkableProperties)
        _createHasGetter(imports, property, resolver, entryAssetPath),
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
      field.name != 'hashCode' &&
      !field.isStatic &&
      field.type is! FunctionType;

  Future<Method> _createHasGetter(
    List<LibraryElement> imports,
    _CheckableProperty property,
    Resolver resolver,
    String entryAssetPath,
  ) async {
    final typeElement = property.element;
    String? import;
    if (typeElement != null) {
      import = await _findImportFor(
        imports,
        typeElement,
        resolver,
        entryAssetPath,
      );
    }
    final name = property.name;
    return Method(
      (b) => b
        ..name = name
        ..type = MethodType.getter
        ..returns = TypeReference(
          (b) => b
            ..symbol = 'Subject'
            ..url = 'package:checks/context.dart'
            ..types.add(refer(property.type.getDisplayString(), import)),
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

  List<_CheckableProperty> _getCheckableProperties(Element element) {
    final properties = <_CheckableProperty>[];

    if (element is InterfaceElement) {
      for (final field in element.fields) {
        if (_isCheckableField(field)) {
          final type = field.type;
          Element? typeElement;
          if (type is InterfaceType) {
            typeElement = type.element;
          }
          final name = field.name;
          if (name != null) {
            properties.add(_CheckableProperty(name, type, typeElement));
          }
        }
      }
    } else if (element is ExtensionTypeElement) {
      for (final getter in element.getters) {
        if (!getter.isStatic && getter.name != 'hashCode') {
          final type = getter.returnType;
          if (type is! FunctionType) {
            Element? typeElement;
            if (type is InterfaceType) {
              typeElement = type.element;
            }
            final name = getter.name;
            if (name != null) {
              properties.add(_CheckableProperty(name, type, typeElement));
            }
          }
        }
      }
    }
    return properties;
  }

  Future<List<String>> _extractTypeNamesFromAst(
    ast.CompilationUnit compilationUnit,
    String expectedImport,
  ) async {
    for (final directive in compilationUnit.directives) {
      bool isTargetDirective = false;
      if (directive is ast.ImportDirective) {
        isTargetDirective = directive.uri.stringValue == expectedImport;
      } else if (directive is ast.ExportDirective) {
        isTargetDirective = directive.uri.stringValue == expectedImport;
      }

      if (isTargetDirective) {
        for (final annotation in directive.metadata) {
          if (annotation.name.name == 'CheckExtensions') {
            final arguments = annotation.arguments?.arguments;
            if (arguments != null && arguments.isNotEmpty) {
              final typesArg = arguments.first;
              if (typesArg is ast.ListLiteral) {
                return typesArg.elements
                    .whereType<ast.Identifier>()
                    .map((e) => e.name)
                    .toList();
              }
            }
          }
        }
      }
    }
    return [];
  }

  Element? _findElementByName(
    LibraryElement currentLibrary,
    List<LibraryElement> imports,
    String name,
  ) {
    final element = currentLibrary.exportNamespace.get2(name);
    if (element != null) return element;

    for (final import in imports) {
      final element = import.exportNamespace.get2(name);
      if (element != null) {
        return element;
      }
    }
    return null;
  }
}

class _CheckableProperty {
  final String name;
  final DartType type;
  final Element? element;

  _CheckableProperty(this.name, this.type, this.element);
}
