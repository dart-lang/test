// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.parse_metadata;

import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../backend/metadata.dart';
import '../frontend/timeout.dart';
import '../util/dart.dart';

/// The valid argument names for [new Duration].
const _durationArgs = const [
  "days",
  "hours",
  "minutes",
  "seconds",
  "milliseconds",
  "microseconds"
];

/// Parse the test metadata for the test file at [path].
///
/// Throws an [AnalysisError] if parsing fails or a [FormatException] if the
/// test annotations are incorrect.
Metadata parseMetadata(String path) {
  var timeout;
  var testOn;

  var contents = new File(path).readAsStringSync();
  var directives = parseDirectives(contents, name: path).directives;
  var annotations = directives.isEmpty ? [] : directives.first.metadata;

  // We explicitly *don't* just look for "package:test" imports here,
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

    if (name == 'TestOn') {
      if (testOn != null) {
        throw new SourceSpanFormatException(
            "Only a single TestOn annotation may be used for a given test file.",
            _spanFor(annotation, path));
      }
      testOn = _parseTestOn(annotation, constructorName, path);
    } else if (name == 'Timeout') {
      if (timeout != null) {
        throw new SourceSpanFormatException(
            "Only a single Timeout annotation may be used for a given test file.",
            _spanFor(annotation, path));
      }
      timeout = _parseTimeout(annotation, constructorName, path);
    }
  }

  try {
    return new Metadata.parse(
        testOn: testOn == null ? null : testOn.stringValue,
        timeout: timeout);
  } on SourceSpanFormatException catch (error) {
    var file = new SourceFile(new File(path).readAsStringSync(),
        url: p.toUri(path));
    var span = contextualizeSpan(error.span, testOn, file);
    if (span == null) rethrow;
    throw new SourceSpanFormatException(error.message, span);
  }
}

/// Parses a `@TestOn` annotation.
///
/// [annotation] is the annotation. [constructorName] is the name of the named
/// constructor for the annotation, if any. [path] is the path to the file from
/// which the annotation was parsed.
StringLiteral _parseTestOn(Annotation annotation, String constructorName,
    String path) {
  if (constructorName != null) {
    throw new SourceSpanFormatException(
        'TestOn doesn\'t have a constructor named "$constructorName".',
        _spanFor(annotation, path));
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

  return args.first;
}

/// Parses a `@Timeout` annotation.
///
/// [annotation] is the annotation. [constructorName] is the name of the named
/// constructor for the annotation, if any. [path] is the path to the file from
/// which the annotation was parsed.
Timeout _parseTimeout(Annotation annotation, String constructorName,
    String path) {
  if (constructorName != null && constructorName != 'factor') {
    throw new SourceSpanFormatException(
        'Timeout doesn\'t have a constructor named "$constructorName".',
        _spanFor(annotation, path));
  }

  var description = 'Timeout';
  if (constructorName != null) description += '.$constructorName'; 

  if (annotation.arguments == null) {
    throw new SourceSpanFormatException(
        '$description takes one argument.', _spanFor(annotation, path));
  }

  var args = annotation.arguments.arguments;
  if (args.isEmpty) {
    throw new SourceSpanFormatException(
        '$description takes one argument.',
        _spanFor(annotation.arguments, path));
  }

  if (args.first is NamedExpression) {
    throw new SourceSpanFormatException(
        "$description doesn't take named parameters.",
        _spanFor(args.first, path));
  }

  if (args.length > 1) {
    throw new SourceSpanFormatException(
        "$description takes only one argument.",
        _spanFor(annotation.arguments, path));
  }

  if (constructorName == null) {
    return new Timeout(_parseDuration(args.first, path));
  } else {
    return new Timeout.factor(_parseNum(args.first, path));
  }
}

/// Parses a `const Duration` expression.
Duration _parseDuration(Expression expression, String path) {
  if (expression is! InstanceCreationExpression) {
    throw new SourceSpanFormatException(
        "Expected a Duration.",
        _spanFor(expression, path));
  }

  var constructor = expression as InstanceCreationExpression;
  if (constructor.constructorName.type.name.name != 'Duration') {
    throw new SourceSpanFormatException(
        "Expected a Duration.",
        _spanFor(constructor, path));
  }

  if (constructor.keyword.lexeme != "const") {
    throw new SourceSpanFormatException(
        "Duration must use a const constructor.",
        _spanFor(constructor, path));
  }

  if (constructor.constructorName.name != null) {
    throw new SourceSpanFormatException(
        "Duration doesn't have a constructor named "
            '"${constructor.constructorName}".',
        _spanFor(constructor.constructorName, path));
  }

  var values = {};
  var args = constructor.argumentList.arguments;
  for (var argument in args) {
    if (argument is! NamedExpression) {
      throw new SourceSpanFormatException(
          "Duration doesn't take positional arguments.",
          _spanFor(argument, path));
    }

    var name = argument.name.label.name;
    if (!_durationArgs.contains(name)) {
      throw new SourceSpanFormatException(
          'Duration doesn\'t take an argument named "$name".',
          _spanFor(argument, path));
    }

    if (values.containsKey(name)) {
      throw new SourceSpanFormatException(
          'An argument named "$name" was already passed.',
          _spanFor(argument, path));
    }

    values[name] = _parseInt(argument.expression, path);
  }

  return new Duration(
      days: values["days"] == null ? 0 : values["days"],
      hours: values["hours"] == null ? 0 : values["hours"],
      minutes: values["minutes"] == null ? 0 : values["minutes"],
      seconds: values["seconds"] == null ? 0 : values["seconds"],
      milliseconds: values["milliseconds"] == null ? 0 : values["milliseconds"],
      microseconds:
          values["microseconds"] == null ? 0 : values["microseconds"]);
}

/// Parses a constant number literal.
num _parseNum(Expression expression, String path) {
  if (expression is IntegerLiteral) return expression.value;
  if (expression is DoubleLiteral) return expression.value;
  throw new SourceSpanFormatException(
      "Expected a number.", _spanFor(expression, path));
}

/// Parses a constant int literal.
int _parseInt(Expression expression, String path) {
  if (expression is IntegerLiteral) return expression.value;
  throw new SourceSpanFormatException(
      "Expected an integer.", _spanFor(expression, path));
}

/// Creates a [SourceSpan] for [node].
SourceSpan _spanFor(AstNode node, String path) =>
    // Load a SourceFile from scratch here since we're only ever going to emit
    // one error per file anyway.
    new SourceFile(new File(path).readAsStringSync(), url: p.toUri(path))
        .span(node.offset, node.end);
