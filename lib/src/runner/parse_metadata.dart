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
import '../backend/platform_selector.dart';
import '../frontend/timeout.dart';
import '../util/dart.dart';
import '../utils.dart';

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
    var onPlatform;

    for (var annotation in _annotations) {
      var pair = _resolveConstructor(
          annotation.name, annotation.constructorName);
      var name = pair.first;
      var constructorName = pair.last;

      if (name == 'TestOn') {
        _assertSingle(testOn, 'TestOn', annotation);
        testOn = _parseTestOn(annotation, constructorName);
      } else if (name == 'Timeout') {
        _assertSingle(timeout, 'Timeout', annotation);
        timeout = _parseTimeout(annotation, constructorName);
      } else if (name == 'Skip') {
        _assertSingle(skip, 'Skip', annotation);
        skip = _parseSkip(annotation, constructorName);
      } else if (name == 'OnPlatform') {
        _assertSingle(onPlatform, 'OnPlatform', annotation);
        onPlatform = _parseOnPlatform(annotation, constructorName);
      }
    }

    return new Metadata(
        testOn: testOn,
        timeout: timeout,
        skip: skip != null,
        skipReason: skip is String ? skip : null,
        onPlatform: onPlatform);
  }

  /// Parses a `@TestOn` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  PlatformSelector _parseTestOn(Annotation annotation, String constructorName) {
    _assertConstructorName(constructorName, 'TestOn', annotation);
    _assertArguments(annotation.arguments, 'TestOn', annotation, positional: 1);
    var literal = _parseString(annotation.arguments.arguments.first);
    return _contextualize(literal,
        () => new PlatformSelector.parse(literal.stringValue));
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

  /// Parses a `Timeout` constructor.
  Timeout _parseTimeoutConstructor(InstanceCreationExpression constructor) {
    var name = _parseConstructor(constructor, 'Timeout',
        validNames: [null, 'factor']);

    var description = 'Timeout';
    if (name != null) description += '.$name';

    _assertArguments(constructor.argumentList, description, constructor,
        positional: 1);

    var args = constructor.argumentList.arguments;
    if (name == null) return new Timeout(_parseDuration(args.first));
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

  /// Parses a `Skip` constructor.
  ///
  /// Returns either `true` or a reason string.
  _parseSkipConstructor(InstanceCreationExpression constructor) {
    _parseConstructor(constructor, 'Skip');
    _assertArguments(constructor.argumentList, 'Skip', constructor,
        optional: 1);

    var args = constructor.argumentList.arguments;
    return args.isEmpty ? true : _parseString(args.first).stringValue;
  }

  /// Parses an `@OnPlatform` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  Map<PlatformSelector, Metadata> _parseOnPlatform(Annotation annotation,
      String constructorName) {
    _assertConstructorName(constructorName, 'OnPlatform', annotation);
    _assertArguments(annotation.arguments, 'OnPlatform', annotation,
        positional: 1);

    return _parseMap(annotation.arguments.arguments.first, key: (key) {
      var selector = _parseString(key);
      return _contextualize(selector,
          () => new PlatformSelector.parse(selector.stringValue));
    }, value: (value) {
      var expressions = [];
      if (value is ListLiteral) {
        expressions = _parseList(value);
      } else if (value is InstanceCreationExpression) {
        expressions = [value];
      } else {
        throw new SourceSpanFormatException(
            'Expected a Timeout, Skip, or List of those.',
            _spanFor(value));
      }

      var timeout;
      var skip;
      for (var expression in expressions) {
        var className = expression is InstanceCreationExpression
            ? _resolveConstructor(
                expression.constructorName.type.name,
                expression.constructorName.name).first
            : null;

        if (className == 'Timeout') {
          _assertSingle(timeout, 'Timeout', expression);
          timeout = _parseTimeoutConstructor(expression);
        } else if (className == 'Skip') {
          _assertSingle(skip, 'Skip', expression);
          skip = _parseSkipConstructor(expression);
        } else {
          throw new SourceSpanFormatException(
              'Expected a Timeout or Skip.',
              _spanFor(expression));
        }
      }

      return new Metadata.parse(timeout: timeout, skip: skip);
    });
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
  void _assertSingle(Object existing, String name, AstNode node) {
    if (existing == null) return;
    throw new SourceSpanFormatException(
        "Only a single $name may be used.", _spanFor(node));
  }

  /// Resolves a constructor name from its type [identifier] and its
  /// [constructorName].
  ///
  /// Since the parsed file isn't fully resolved, this is necessary to
  /// disambiguate between prefixed names and named constructors.
  Pair<String, String> _resolveConstructor(Identifier identifier,
      SimpleIdentifier constructorName) {
    // The syntax is ambiguous between named constructors and prefixed
    // annotations, so we need to resolve that ambiguity using the known
    // prefixes. The analyzer parses "new x.y()" as prefix "x", annotation "y",
    // and named constructor null. It parses "new x.y.z()" as prefix "x",
    // annotation "y", and named constructor "z".
    var className;
    var namedConstructor;
    if (identifier is PrefixedIdentifier &&
        !_prefixes.contains(identifier.prefix.name) &&
        constructorName == null) {
      className = identifier.prefix.name;
      namedConstructor = identifier.identifier.name;
    } else {
      className = identifier is PrefixedIdentifier
          ? identifier.identifier.name
          : identifier.name;
      if (constructorName != null) namedConstructor = constructorName.name;
    }
    return new Pair(className, namedConstructor);
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
    var pair = _resolveConstructor(
        constructor.constructorName.type.name,
        constructor.constructorName.name);
    var actualClassName = pair.first;
    var constructorName = pair.last;

    if (actualClassName != className) {
      throw new SourceSpanFormatException(
          "Expected a $className.", _spanFor(constructor));
    }

    if (constructor.keyword.lexeme != "const") {
      throw new SourceSpanFormatException(
          "$className must use a const constructor.", _spanFor(constructor));
    }

    _assertConstructorName(constructorName, className, expression,
        validNames: validNames);
    return constructorName;
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

  /// Parses a Map literal.
  ///
  /// By default, returns [Expression] keys and values. These can be overridden
  /// with the [key] and [value] parameters.
  Map _parseMap(Expression expression, {key(Expression expression),
      value(Expression expression)}) {
    if (key == null) key = (expression) => expression;
    if (value == null) value = (expression) => expression;

    if (expression is! MapLiteral) {
      throw new SourceSpanFormatException(
          "Expected a Map.", _spanFor(expression));
    }

    var map = expression as MapLiteral;
    if (map.constKeyword == null) {
      throw new SourceSpanFormatException(
          "Map literals must be const.", _spanFor(map));
    }

    return new Map.fromIterable(map.entries,
        key: (entry) => key(entry.key),
        value: (entry) => value(entry.value));
  }

  /// Parses a List literal.
  List<Expression> _parseList(Expression expression) {
    if (expression is! ListLiteral) {
      throw new SourceSpanFormatException(
          "Expected a List.", _spanFor(expression));
    }

    var list = expression as ListLiteral;
    if (list.constKeyword == null) {
      throw new SourceSpanFormatException(
          "List literals must be const.", _spanFor(list));
    }

    return list.elements;
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

  /// Runs [fn] and contextualizes any [SourceSpanFormatException]s that occur
  /// in it relative to [literal].
  _contextualize(StringLiteral literal, fn()) {
    try {
      return fn();
    } on SourceSpanFormatException catch (error) {
      var file = new SourceFile(new File(_path).readAsStringSync(),
          url: p.toUri(_path));
      var span = contextualizeSpan(error.span, literal, file);
      if (span == null) rethrow;
      throw new SourceSpanFormatException(error.message, span);
    }
  }
}
