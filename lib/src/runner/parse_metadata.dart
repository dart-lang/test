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

/// Parse the test metadata for the test file at [path].
///
/// Throws an [AnalysisError] if parsing fails or a [FormatException] if the
/// test annotations are incorrect.
Metadata parseMetadata(String path) => new _Parser(path).parse();

/// A parser for test suite metadata.
class _Parser {
  /// The path to the test suite.
  final String _path;

  /// All annotations at the top of the file.
  List<Annotation> _annotations;

  /// All prefixes defined by imports in this file.
  Set<String> _prefixes;

  _Parser(String path)
      : _path = path {
    var contents = new File(path).readAsStringSync();
    var directives = parseDirectives(contents, name: path).directives;
    _annotations = directives.isEmpty ? [] : directives.first.metadata;

    // We explicitly *don't* just look for "package:test" imports here,
    // because it could be re-exported from another library.
    _prefixes = directives.map((directive) {
      if (directive is! ImportDirective) return null;
      if (directive.prefix == null) return null;
      return directive.prefix.name;
    }).where((prefix) => prefix != null).toSet();
  }

  /// Parses the metadata.
  Metadata parse() {
    var timeout;
    var testOn;
    var skip;

    for (var annotation in _annotations) {
      // The annotation syntax is ambiguous between named constructors and
      // prefixed annotations, so we need to resolve that ambiguity using the
      // known prefixes. The analyzer parses "@x.y()" as prefix "x", annotation
      // "y", and named constructor null. It parses "@x.y.z()" as prefix "x",
      // annotation "y", and named constructor "z".
      var name;
      var constructorName;
      var identifier = annotation.name;
      if (identifier is PrefixedIdentifier &&
          !_prefixes.contains(identifier.prefix.name) &&
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
        _assertSingleAnnotation(testOn, 'TestOn', annotation);
        testOn = _parseTestOn(annotation, constructorName);
      } else if (name == 'Timeout') {
        _assertSingleAnnotation(timeout, 'Timeout', annotation);
        timeout = _parseTimeout(annotation, constructorName);
      } else if (name == 'Skip') {
        _assertSingleAnnotation(skip, 'Skip', annotation);
        skip = _parseSkip(annotation, constructorName);
      }
    }

    try {
      return new Metadata.parse(
          testOn: testOn == null ? null : testOn.stringValue,
          timeout: timeout,
          skip: skip);
    } on SourceSpanFormatException catch (error) {
      var file = new SourceFile(new File(_path).readAsStringSync(),
          url: p.toUri(_path));
      var span = contextualizeSpan(error.span, testOn, file);
      if (span == null) rethrow;
      throw new SourceSpanFormatException(error.message, span);
    }
  }

  /// Parses a `@TestOn` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  StringLiteral _parseTestOn(Annotation annotation, String constructorName) {
    _assertConstructorName(constructorName, 'TestOn', annotation);
    _assertArguments(annotation.arguments, 'TestOn', annotation, positional: 1);
    return _parseString(annotation.arguments.arguments.first);
  }

  /// Parses a `@Timeout` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  Timeout _parseTimeout(Annotation annotation, String constructorName) {
    _assertConstructorName(constructorName, 'Timeout', annotation,
        validNames: [null, 'factor']);

    var description = 'Timeout';
    if (constructorName != null) description += '.$constructorName'; 

    _assertArguments(annotation.arguments, description, annotation,
        positional: 1);

    var args = annotation.arguments.arguments;
    if (constructorName == null) return new Timeout(_parseDuration(args.first));
    return new Timeout.factor(_parseNum(args.first));
  }

  /// Parses a `@Skip` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  ///
  /// Returns either `true` or a reason string.
  _parseSkip(Annotation annotation, String constructorName) {
    _assertConstructorName(constructorName, 'Skip', annotation);
    _assertArguments(annotation.arguments, 'Skip', annotation, optional: 1);

    var args = annotation.arguments.arguments;
    return args.isEmpty ? true : _parseString(args.first).stringValue;
  }

  /// Parses a `const Duration` expression.
  Duration _parseDuration(Expression expression) {
    _parseConstructor(expression, 'Duration');

    var constructor = expression as InstanceCreationExpression;
    var values = _assertArguments(
        constructor.argumentList, 'Duration', constructor, named: [
      'days', 'hours', 'minutes', 'seconds', 'milliseconds', 'microseconds'
    ]);

    for (var key in values.keys.toList()) {
      if (values.containsKey(key)) values[key] = _parseInt(values[key]);
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

  /// Asserts that [existing] is null.
  ///
  /// [name] is the name of the annotation and [node] is its location, used for
  /// error reporting.
  void _assertSingleAnnotation(Object existing, String name, AstNode node) {
    if (existing == null) return;
    throw new SourceSpanFormatException(
        "Only a single $name annotation may be used for a given test file.",
        _spanFor(node));
  }

  /// Asserts that [constructorName] is a valid constructor name for an AST
  /// node.
  ///
  /// [nodeName] is the name of the class being constructed, and [node] is the
  /// AST node for that class. [validNames], if passed, is the set of valid
  /// constructor names; if an unnamed constructor is valid, it should include
  /// `null`. By default, only an unnamed constructor is allowed.
  void _assertConstructorName(String constructorName, String nodeName,
      AstNode node, {Iterable<String> validNames}) {
    if (validNames == null) validNames = [null];
    if (validNames.contains(constructorName)) return;

    if (constructorName == null) {
      throw new SourceSpanFormatException(
          "$nodeName doesn't have an unnamed constructor.",
          _spanFor(node));
    } else {
      throw new SourceSpanFormatException(
          '$nodeName doesn\'t have a constructor named "$constructorName".',
          _spanFor(node));
    }
  }

  /// Parses a constructor invocation for [className].
  ///
  /// [validNames], if passed, is the set of valid constructor names; if an
  /// unnamed constructor is valid, it should include `null`. By default, only
  /// an unnamed constructor is allowed.
  ///
  /// Returns the name of the named constructor, if any.
  String _parseConstructor(Expression expression, String className,
      {Iterable<String> validNames}) {
    if (validNames == null) validNames = [null];

    if (expression is! InstanceCreationExpression) {
      throw new SourceSpanFormatException(
          "Expected a $className.", _spanFor(expression));
    }

    var constructor = expression as InstanceCreationExpression;
    if (constructor.constructorName.type.name.name != className) {
      throw new SourceSpanFormatException(
          "Expected a $className.", _spanFor(constructor));
    }

    if (constructor.keyword.lexeme != "const") {
      throw new SourceSpanFormatException(
          "$className must use a const constructor.", _spanFor(constructor));
    }

    var name = constructor.constructorName == null
        ? null
        : constructor.constructorName.name;
    _assertConstructorName(name, className, expression,
        validNames: validNames);
    return name;
  }

  /// Assert that [arguments] is a valid argument list.
  ///
  /// [name] describes the function and [node] is its AST node. [positional] is
  /// the number of required positional arguments, [optional] the number of
  /// optional positional arguments, and [named] the set of valid argument
  /// names.
  ///
  /// The set of parsed named arguments is returned.
  Map<String, Expression> _assertArguments(ArgumentList arguments, String name,
      AstNode node, {int positional, int optional, Iterable<String> named}) {
    if (positional == null) positional = 0;
    if (optional == null) optional = 0;
    if (named == null) named = new Set();

    if (arguments == null) {
      throw new SourceSpanFormatException(
          '$name takes arguments.', _spanFor(node));
    }

    var actualNamed = arguments.arguments
        .where((arg) => arg is NamedExpression).toList();
    if (!actualNamed.isEmpty && named.isEmpty) {
      throw new SourceSpanFormatException(
          "$name doesn't take named arguments.", _spanFor(actualNamed.first));
    }

    var namedValues = {};
    for (var argument in actualNamed) {
      var argumentName = argument.name.label.name;
      if (!named.contains(argumentName)) {
        throw new SourceSpanFormatException(
            '$name doesn\'t take an argument named "$argumentName".',
            _spanFor(argument));
      } else if (namedValues.containsKey(argumentName)) {
        throw new SourceSpanFormatException(
            'An argument named "$argumentName" was already passed.',
            _spanFor(argument));
      } else {
        namedValues[argumentName] = argument.expression;
      }
    }

    var actualPositional = arguments.arguments.length - actualNamed.length;
    if (actualPositional < positional) {
      var buffer = new StringBuffer("$name takes ");
      if (optional != 0) buffer.write("at least ");
      buffer.write("$positional argument");
      if (positional > 1) buffer.write("s");
      buffer.write(".");
      throw new SourceSpanFormatException(
          buffer.toString(), _spanFor(arguments));
    }

    if (actualPositional > positional + optional) {
      if (optional + positional == 0) {
        var buffer = new StringBuffer("$name doesn't take ");
        if (!named.isEmpty) buffer.write("positional ");
        buffer.write("arguments.");
        throw new SourceSpanFormatException(
            buffer.toString(), _spanFor(arguments));
      }

      var buffer = new StringBuffer("$name takes ");
      if (optional != 0) buffer.write("at most ");
      buffer.write("${positional + optional} argument");
      if (positional > 1) buffer.write("s");
      buffer.write(".");
      throw new SourceSpanFormatException(
          buffer.toString(), _spanFor(arguments));
    }

    return namedValues;
  }

  /// Parses a constant number literal.
  num _parseNum(Expression expression) {
    if (expression is IntegerLiteral) return expression.value;
    if (expression is DoubleLiteral) return expression.value;
    throw new SourceSpanFormatException(
        "Expected a number.", _spanFor(expression));
  }

  /// Parses a constant int literal.
  int _parseInt(Expression expression) {
    if (expression is IntegerLiteral) return expression.value;
    throw new SourceSpanFormatException(
        "Expected an integer.", _spanFor(expression));
  }

  /// Parses a constant String literal.
  StringLiteral _parseString(Expression expression) {
    if (expression is StringLiteral) return expression;
    throw new SourceSpanFormatException(
        "Expected a String.", _spanFor(expression));
  }

  /// Creates a [SourceSpan] for [node].
  SourceSpan _spanFor(AstNode node) {
    // Load a SourceFile from scratch here since we're only ever going to emit
    // one error per file anyway.
    var contents = new File(_path).readAsStringSync();
    return new SourceFile(contents, url: p.toUri(_path))
        .span(node.offset, node.end);
  }
}
