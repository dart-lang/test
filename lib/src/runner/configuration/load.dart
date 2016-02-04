// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import '../../utils.dart';
import '../../frontend/timeout.dart';
import '../../backend/test_platform.dart';
import '../configuration.dart';
import 'values.dart';

/// Loads configuration information from a YAML file at [path].
///
/// Throws a [FormatException] if the configuration is invalid, and a
/// [FileSystemException] if it can't be read.
Configuration load(String path) {
  var source = new File(path).readAsStringSync();
  var document = loadYamlNode(source, sourceUrl: p.toUri(path));

  if (document.value == null) return new Configuration();

  if (document is! Map) {
    throw new SourceSpanFormatException(
        "The configuration must be a YAML map.", document.span, source);
  }

  var loader = new _ConfigurationLoader(document, source);
  return loader.load();
}

/// A helper for [load] that tracks the YAML document.
class _ConfigurationLoader {
  /// The parsed configuration document.
  final YamlMap _document;

  /// The source string for [_document].
  ///
  /// Used for error reporting.
  final String _source;

  _ConfigurationLoader(this._document, this._source);

  /// Loads the configuration in [_document].
  Configuration load() {
    var verboseTrace = _getBool("verbose_trace");
    var jsTrace = _getBool("js_trace");

    var reporter = _getString("reporter");
    if (reporter != null && !allReporters.contains(reporter)) {
      _error('Unknown reporter "$reporter".', "reporter");
    }

    var pubServePort = _getInt("pub_serve");
    var concurrency = _getInt("concurrency");
    var timeout = _parseValue("timeout", (value) => new Timeout.parse(value));

    var allPlatformIdentifiers =
        TestPlatform.all.map((platform) => platform.identifier).toSet();
    var platforms = _getList("platforms", (platformNode) {
      _validate(platformNode, "Platforms must be strings.",
          (value) => value is String);
      _validate(platformNode, 'Unknown platform "${platformNode.value}".',
          allPlatformIdentifiers.contains);

      return TestPlatform.find(platformNode.value);
    });

    // TODO(nweiz): Add support for using globs to define defaults paths to run.

    return new Configuration(
        verboseTrace: verboseTrace,
        jsTrace: jsTrace,
        reporter: reporter,
        pubServePort: pubServePort,
        concurrency: concurrency,
        timeout: timeout,
        platforms: platforms);
  }

  /// Throws an exception with [message] if [test] returns `false` when passed
  /// [node]'s value.
  void _validate(YamlNode node, String message, bool test(value)) {
    if (test(node.value)) return;
    throw new SourceSpanFormatException(message, node.span, _source);
  }

  /// Returns the value of the node at [field].
  ///
  /// If [typeTest] returns `false` for that value, instead throws an error
  /// complaining that the field is not a [typeName].
  _getValue(String field, String typeName, bool typeTest(value)) {
    var value = _document[field];
    if (value == null || typeTest(value)) return value;
    _error("$field must be ${a(typeName)}.", field);
  }

  /// Returns the YAML node at [field].
  ///
  /// If [typeTest] returns `false` for that node's value, instead throws an
  /// error complaining that the field is not a [typeName].
  YamlNode _getNode(String field, String typeName, bool typeTest(value)) {
    var node = _document.nodes[field];
    if (node == null) return null;
    _validate(node, "$field must be ${a(typeName)}.", typeTest);
    return node;
  }

  /// Asserts that [field] is an int and returns its value.
  int _getInt(String field) =>
      _getValue(field, "int", (value) => value is int);

  /// Asserts that [field] is a boolean and returns its value.
  bool _getBool(String field) =>
      _getValue(field, "boolean", (value) => value is bool);

  /// Asserts that [field] is a string and returns its value.
  String _getString(String field) =>
      _getValue(field, "string", (value) => value is String);

  /// Asserts that [field] is a list and runs [forElement] for each element it
  /// contains.
  ///
  /// Returns a list of values returned by [forElement].
  List _getList(String field, forElement(YamlNode elementNode)) {
    var node = _getNode(field, "list", (value) => value is List);
    if (node == null) return [];
    return node.nodes.map(forElement).toList();
  }

  /// Asserts that [field] is a string, passes it to [parse], and returns the
  /// result.
  ///
  /// If [parse] throws a [FormatException], it's wrapped to include [field]'s
  /// span.
  _parseValue(String field, parse(value)) {
    var value = _getString(field);
    if (value == null) return null;

    try {
      return parse(value);
    } on FormatException catch (error) {
      _error('Invalid $field: ${error.message}', field);
    }
  }

  /// Throws a [SourceSpanFormatException] with [message] about [field].
  void _error(String message, String field) {
    throw new SourceSpanFormatException(
        message, _document.nodes[field].span, _source);
  }
}
