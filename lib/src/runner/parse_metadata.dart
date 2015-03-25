// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.parse_metadata;

import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../backend/metadata.dart';
import '../util/dart.dart';

/// Parse the test metadata for the test file at [path].
///
/// Throws an [AnalysisError] if parsing fails or a [FormatException] if the
/// test annotations are incorrect.
Metadata parseMetadata(String path) {
  var testOn;

  var contents = new File(path).readAsStringSync();
  var directives = parseDirectives(contents, name: path).directives;
  var annotations = directives.isEmpty ? [] : directives.first.metadata;

  // We explicitly *don't* just look for "package:unittest" imports here,
  // because it could be re-exported from another library.
  var prefixes = directives.map((directive) {
    if (directive is! ImportDirective) return null;
    if (directive.prefix == null) return null;
    return directive.prefix.name;
  }).where((prefix) => prefix != null).toSet();

  for (var annotation in annotations) {
    // The annotation syntax is ambiguous between named constructors and
    // prefixed annotations, so we need to resolve that ambiguity using the
    // known prefixes. The analyzer parses "@x.y()" as prefix "x", annotation
    // "y", and named constructor null. It parses "@x.y.z()" as prefix "x",
    // annotation "y", and named constructor "z".
    var name;
    var constructorName;
    var identifier = annotation.name;
    if (identifier is PrefixedIdentifier &&
        !prefixes.contains(identifier.prefix.name) &&
        annotation.constructorName == null) {
      name = identifier.prefix.name;
      constructorName = identifier.identifier.name;
    } else {
      name = identifier is PrefixedIdentifier
          ? identifier.identifier.name
          : identifier.name;
      if (annotation.constructorName != null) {
        constructorName = annotation.constructorName.name;
      }
    }

    if (name != 'TestOn') continue;
    if (constructorName != null) {
      throw new SourceSpanFormatException(
          'TestOn doesn\'t have a constructor named "$constructorName".',
          _spanFor(identifier.identifier, path));
    }

    if (annotation.arguments == null) {
      throw new SourceSpanFormatException(
          'TestOn takes one argument.', _spanFor(annotation, path));
    }

    var args = annotation.arguments.arguments;
    if (args.isEmpty) {
      throw new SourceSpanFormatException(
          'TestOn takes one argument.', _spanFor(annotation.arguments, path));
    }

    if (args.first is NamedExpression) {
      throw new SourceSpanFormatException(
          "TestOn doesn't take named parameters.", _spanFor(args.first, path));
    }

    if (args.length > 1) {
      throw new SourceSpanFormatException(
          "TestOn takes only one argument.",
          _spanFor(annotation.arguments, path));
    }

    if (args.first is! StringLiteral) {
      throw new SourceSpanFormatException(
          "TestOn takes a String.", _spanFor(args.first, path));
    }

    if (testOn != null) {
      throw new SourceSpanFormatException(
          "Only a single TestOn annotation may be used for a given test file.",
          _spanFor(annotation, path));
    }

    testOn = args.first.stringValue;
  }

  return new Metadata.parse(testOn: testOn);
}

/// Creates a [SourceSpan] for [node].
SourceSpan _spanFor(AstNode node, String path) =>
    // Load a SourceFile from scratch here since we're only ever going to emit
    // one error per file anyway.
    new SourceFile(new File(path).readAsStringSync(), url: p.toUri(path))
        .span(node.offset, node.end);
