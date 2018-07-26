// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../backend/metadata.dart';
import '../backend/platform_selector.dart';
import '../frontend/timeout.dart';
import '../util/dart.dart';
import '../utils.dart';

/// Parse the test metadata for the test file at [path].
///
/// The [platformVariables] are the set of variables that are valid for platform
/// selectors in suite metadata, in addition to the built-in variables that are
/// allowed everywhere.
///
/// Throws an [AnalysisError] if parsing fails or a [FormatException] if the
/// test annotations are incorrect.
Metadata parseMetadata(String path, Set<String> platformVariables) =>
    new _Parser(path, platformVariables).parse();

/// A parser for test suite metadata.
class _Parser {
  /// The path to the test suite.
  final String _path;

  /// The set of variables that are valid for platform selectors, in addition to
  /// the built-in variables that are allowed everywhere.
  final Set<String> _platformVariables;

  /// All annotations at the top of the file.
  List<Annotation> _annotations;

  /// All prefixes defined by imports in this file.
  Set<String> _prefixes;

  _Parser(String path, this._platformVariables) : _path = path {
    var contents = new File(path).readAsStringSync();
    var directives = parseDirectives(contents, name: path).directives;
    _annotations = directives.isEmpty ? [] : directives.first.metadata;

    // We explicitly *don't* just look for "package:test" imports here,
    // because it could be re-exported from another library.
    _prefixes = directives
        .map((directive) {
          if (directive is ImportDirective) {
            return directive.prefix?.name;
          } else {
            return null;
          }
        })
        .where((prefix) => prefix != null)
        .toSet();
  }

  /// Parses the metadata.
  Metadata parse() {
    Timeout timeout;
    PlatformSelector testOn;
    dynamic /*String|bool*/ skip;
    Map<PlatformSelector, Metadata> onPlatform;
    Set<String> tags;
    int retry;

    for (var annotation in _annotations) {
      var pair =
          _resolveConstructor(annotation.name, annotation.constructorName);
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
      } else if (name == 'Tags') {
        _assertSingle(tags, 'Tags', annotation);
        tags = _parseTags(annotation, constructorName);
      } else if (name == 'Retry') {
        retry = _parseRetry(annotation, constructorName);
      }
    }

    return new Metadata(
        testOn: testOn,
        timeout: timeout,
        skip: skip == null ? null : true,
        skipReason: skip is String ? skip : null,
        onPlatform: onPlatform,
        tags: tags,
        retry: retry);
  }

  /// Parses a `@TestOn` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  PlatformSelector _parseTestOn(
          Annotation annotation, String constructorName) =>
      _parsePlatformSelector(annotation.arguments.arguments.first);

  /// Parses an [expression] that should contain a string representing a
  /// [PlatformSelector].
  PlatformSelector _parsePlatformSelector(Expression expression) {
    var literal = _parseString(expression);
    return _contextualize(
        literal,
        () => new PlatformSelector.parse(literal.stringValue)
          ..validate(_platformVariables));
  }

  /// Parses a `@Retry` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  int _parseRetry(Annotation annotation, String constructorName) =>
      _parseInt(annotation.arguments.arguments.first);

  /// Parses a `@Timeout` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  Timeout _parseTimeout(Annotation annotation, String constructorName) {
    if (constructorName == 'none') {
      return Timeout.none;
    }

    var args = annotation.arguments.arguments;
    if (constructorName == null) return new Timeout(_parseDuration(args.first));
    return new Timeout.factor(_parseNum(args.first));
  }

  /// Parses a `Timeout` constructor.
  Timeout _parseTimeoutConstructor(InstanceCreationExpression constructor) {
    var name = _parseConstructor(constructor, 'Timeout');
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
    var args = annotation.arguments.arguments;
    return args.isEmpty ? true : _parseString(args.first).stringValue;
  }

  /// Parses a `Skip` constructor.
  ///
  /// Returns either `true` or a reason string.
  _parseSkipConstructor(InstanceCreationExpression constructor) {
    _parseConstructor(constructor, 'Skip');
    var args = constructor.argumentList.arguments;
    return args.isEmpty ? true : _parseString(args.first).stringValue;
  }

  /// Parses a `@Tags` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  Set<String> _parseTags(Annotation annotation, String constructorName) {
    return _parseList(annotation.arguments.arguments.first)
        .map((tagExpression) {
      var name = _parseString(tagExpression).stringValue;
      if (name.contains(anchoredHyphenatedIdentifier)) return name;

      throw new SourceSpanFormatException(
          'Invalid tag name. Tags must be (optionally hyphenated) Dart '
          'identifiers.',
          _spanFor(tagExpression));
    }).toSet();
  }

  /// Parses an `@OnPlatform` annotation.
  ///
  /// [annotation] is the annotation. [constructorName] is the name of the named
  /// constructor for the annotation, if any.
  Map<PlatformSelector, Metadata> _parseOnPlatform(
      Annotation annotation, String constructorName) {
    return _parseMap(annotation.arguments.arguments.first, key: (key) {
      return _parsePlatformSelector(key);
    }, value: (value) {
      var expressions = <AstNode>[];
      if (value is ListLiteral) {
        expressions = _parseList(value);
      } else if (value is InstanceCreationExpression ||
          value is PrefixedIdentifier) {
        expressions = [value];
      } else {
        throw new SourceSpanFormatException(
            'Expected a Timeout, Skip, or List of those.', _spanFor(value));
      }

      Timeout timeout;
      dynamic skip;
      for (var expression in expressions) {
        if (expression is InstanceCreationExpression) {
          var className = _resolveConstructor(
                  expression.constructorName.type.name,
                  expression.constructorName.name)
              .first;

          if (className == 'Timeout') {
            _assertSingle(timeout, 'Timeout', expression);
            timeout = _parseTimeoutConstructor(expression);
            continue;
          } else if (className == 'Skip') {
            _assertSingle(skip, 'Skip', expression);
            skip = _parseSkipConstructor(expression);
            continue;
          }
        } else if (expression is PrefixedIdentifier &&
            expression.prefix.name == 'Timeout') {
          if (expression.identifier.name != 'none') {
            throw new SourceSpanFormatException(
                'Undefined value.', _spanFor(expression));
          }

          _assertSingle(timeout, 'Timeout', expression);
          timeout = Timeout.none;
          continue;
        }

        throw new SourceSpanFormatException(
            'Expected a Timeout or Skip.', _spanFor(expression));
      }

      return new Metadata.parse(timeout: timeout, skip: skip);
    });
  }

  /// Parses a `const Duration` expression.
  Duration _parseDuration(Expression expression) {
    _parseConstructor(expression, 'Duration');

    var constructor = expression as InstanceCreationExpression;
    var values = _parseNamedArguments(constructor.argumentList)
        .map((key, value) => new MapEntry(key, _parseInt(value)));

    return new Duration(
        days: values['days'] ?? 0,
        hours: values['hours'] ?? 0,
        minutes: values['minutes'] ?? 0,
        seconds: values['seconds'] ?? 0,
        milliseconds: values['milliseconds'] ?? 0,
        microseconds: values['microseconds'] ?? 0);
  }

  Map<String, Expression> _parseNamedArguments(ArgumentList arguments) =>
      new Map.fromIterable(
          arguments.arguments.where((a) => a is NamedExpression),
          key: (a) => (a as NamedExpression).name.label.name,
          value: (a) => (a as NamedExpression).expression);

  /// Asserts that [existing] is null.
  ///
  /// [name] is the name of the annotation and [node] is its location, used for
  /// error reporting.
  void _assertSingle(Object existing, String name, AstNode node) {
    if (existing == null) return;
    throw new SourceSpanFormatException(
        'Only a single $name may be used.', _spanFor(node));
  }

  /// Resolves a constructor name from its type [identifier] and its
  /// [constructorName].
  ///
  /// Since the parsed file isn't fully resolved, this is necessary to
  /// disambiguate between prefixed names and named constructors.
  Pair<String, String> _resolveConstructor(
      Identifier identifier, SimpleIdentifier constructorName) {
    // The syntax is ambiguous between named constructors and prefixed
    // annotations, so we need to resolve that ambiguity using the known
    // prefixes. The analyzer parses "new x.y()" as prefix "x", annotation "y",
    // and named constructor null. It parses "new x.y.z()" as prefix "x",
    // annotation "y", and named constructor "z".
    String className;
    String namedConstructor;
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

  /// Parses a constructor invocation for [className].
  ///
  /// [validNames], if passed, is the set of valid constructor names; if an
  /// unnamed constructor is valid, it should include `null`. By default, only
  /// an unnamed constructor is allowed.
  ///
  /// Returns the name of the named constructor, if any.
  String _parseConstructor(Expression expression, String className) {
    if (expression is! InstanceCreationExpression) {
      throw new SourceSpanFormatException(
          'Expected a $className.', _spanFor(expression));
    }

    var constructor = expression as InstanceCreationExpression;
    var pair = _resolveConstructor(constructor.constructorName.type.name,
        constructor.constructorName.name);
    var actualClassName = pair.first;
    var constructorName = pair.last;

    if (actualClassName != className) {
      throw new SourceSpanFormatException(
          'Expected a $className.', _spanFor(constructor));
    }

    return constructorName;
  }

  /// Parses a Map literal.
  ///
  /// By default, returns [Expression] keys and values. These can be overridden
  /// with the [key] and [value] parameters.
  Map<K, V> _parseMap<K, V>(Expression expression,
      {K key(Expression expression), V value(Expression expression)}) {
    key ??= (expression) => expression as K;
    value ??= (expression) => expression as V;

    if (expression is! MapLiteral) {
      throw new SourceSpanFormatException(
          'Expected a Map.', _spanFor(expression));
    }

    var map = expression as MapLiteral;

    return new Map.fromIterables(map.entries.map((e) => key(e.key)),
        map.entries.map((e) => value(e.value)));
  }

  /// Parses a List literal.
  List<Expression> _parseList(Expression expression) {
    if (expression is! ListLiteral) {
      throw new SourceSpanFormatException(
          'Expected a List.', _spanFor(expression));
    }

    var list = expression as ListLiteral;

    return list.elements;
  }

  /// Parses a constant number literal.
  num _parseNum(Expression expression) {
    if (expression is IntegerLiteral) return expression.value;
    if (expression is DoubleLiteral) return expression.value;
    throw new SourceSpanFormatException(
        'Expected a number.', _spanFor(expression));
  }

  /// Parses a constant int literal.
  int _parseInt(Expression expression) {
    if (expression is IntegerLiteral) return expression.value;
    throw new SourceSpanFormatException(
        'Expected an integer.', _spanFor(expression));
  }

  /// Parses a constant String literal.
  StringLiteral _parseString(Expression expression) {
    if (expression is StringLiteral) return expression;
    throw new SourceSpanFormatException(
        'Expected a String.', _spanFor(expression));
  }

  /// Creates a [SourceSpan] for [node].
  SourceSpan _spanFor(AstNode node) {
    // Load a SourceFile from scratch here since we're only ever going to emit
    // one error per file anyway.
    var contents = new File(_path).readAsStringSync();
    return new SourceFile.fromString(contents, url: p.toUri(_path))
        .span(node.offset, node.end);
  }

  /// Runs [fn] and contextualizes any [SourceSpanFormatException]s that occur
  /// in it relative to [literal].
  T _contextualize<T>(StringLiteral literal, T fn()) {
    try {
      return fn();
    } on SourceSpanFormatException catch (error) {
      var file = new SourceFile.fromString(new File(_path).readAsStringSync(),
          url: p.toUri(_path));
      var span = contextualizeSpan(error.span, literal, file);
      if (span == null) rethrow;
      throw new SourceSpanFormatException(error.message, span);
    }
  }
}
