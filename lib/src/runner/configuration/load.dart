// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:boolean_selector/boolean_selector.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import '../../backend/operating_system.dart';
import '../../backend/platform_selector.dart';
import '../../backend/test_platform.dart';
import '../../frontend/timeout.dart';
import '../../utils.dart';
import '../../util/io.dart';
import '../configuration.dart';
import 'values.dart';

/// Loads configuration information from a YAML file at [path].
///
/// Throws a [FormatException] if the configuration is invalid, and a
/// [FileSystemException] if it can't be read.
Configuration load(String path) {
  var source = new File(path).readAsStringSync();
  var document = loadYamlNode(source, sourceUrl: p.toUri(path));

  if (document.value == null) return Configuration.empty;

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

  /// Whether runner configuration is allowed at this level.
  final bool _runnerConfig;

  _ConfigurationLoader(this._document, this._source, {bool runnerConfig: true})
      : _runnerConfig = runnerConfig;

  /// Loads the configuration in [_document].
  Configuration load() => _loadTestConfig().merge(_loadRunnerConfig());

  /// Loads test configuration (but not runner configuration).
  Configuration _loadTestConfig() {
    var verboseTrace = _getBool("verbose_trace");
    var jsTrace = _getBool("js_trace");

    var skip = _getValue("skip", "boolean or string",
        (value) => value is bool || value is String);
    var skipReason;
    if (skip is String) {
      skipReason = skip;
      skip = true;
    }

    var testOn = _parseValue("test_on",
        (value) => new PlatformSelector.parse(value));

    var timeout = _parseValue("timeout", (value) => new Timeout.parse(value));

    var addTags = _getList("add_tags",
        (tagNode) => _parseIdentifierLike(tagNode, "Tag name"));

    var tags = _getMap("tags",
        key: (keyNode) => _parseNode(keyNode, "tags key",
            (value) => new BooleanSelector.parse(value)),
        value: (valueNode) =>
            _nestedConfig(valueNode, "tag value", runnerConfig: false));

    var onPlatform = _getMap("on_platform",
        key: (keyNode) => _parseNode(keyNode, "on_platform key",
            (value) => new PlatformSelector.parse(value)),
        value: (valueNode) =>
            _nestedConfig(valueNode, "on_platform value", runnerConfig: false));

    var onOS = _getMap("on_os", key: (keyNode) {
      _validate(keyNode, "on_os key must be a string.",
          (value) => value is String);

      var os = OperatingSystem.find(keyNode.value);
      if (os != null) return os;

      throw new SourceSpanFormatException(
          'Invalid on_os key: No such operating system.',
          keyNode.span, _source);
    }, value: (valueNode) => _nestedConfig(valueNode, "on_os value"));

    var presets = _getMap("presets",
        key: (keyNode) => _parseIdentifierLike(keyNode, "presets key"),
        value: (valueNode) => _nestedConfig(valueNode, "presets value"));

    var config = new Configuration(
        verboseTrace: verboseTrace,
        jsTrace: jsTrace,
        skip: skip,
        skipReason: skipReason,
        testOn: testOn,
        timeout: timeout,
        addTags: addTags,
        tags: tags,
        onPlatform: onPlatform,
        presets: presets);

    var osConfig = onOS[currentOS];
    return osConfig == null ? config : config.merge(osConfig);
  }

  /// Loads runner configuration (but not test configuration).
  ///
  /// If [_runnerConfig] is `false`, this will error if there are any
  /// runner-level configuration fields.
  Configuration _loadRunnerConfig() {
    if (!_runnerConfig) {
      _disallow("reporter");
      _disallow("pub_serve");
      _disallow("concurrency");
      _disallow("platforms");
      _disallow("paths");
      _disallow("filename");
      _disallow("add_presets");
      return Configuration.empty;
    }

    var reporter = _getString("reporter");
    if (reporter != null && !allReporters.contains(reporter)) {
      _error('Unknown reporter "$reporter".', "reporter");
    }

    var pubServePort = _getInt("pub_serve");
    var concurrency = _getInt("concurrency");

    var allPlatformIdentifiers =
        TestPlatform.all.map((platform) => platform.identifier).toSet();
    var platforms = _getList("platforms", (platformNode) {
      _validate(platformNode, "Platforms must be strings.",
          (value) => value is String);
      _validate(platformNode, 'Unknown platform "${platformNode.value}".',
          allPlatformIdentifiers.contains);

      return TestPlatform.find(platformNode.value);
    });

    var paths = _getList("paths", (pathNode) {
      _validate(pathNode, "Paths must be strings.", (value) => value is String);
      _validate(pathNode, "Paths must be relative.", p.url.isRelative);

      return _parseNode(pathNode, "path", p.fromUri);
    });

    var filename = _parseValue("filename", (value) => new Glob(value));

    var chosenPresets = _getList("add_presets",
        (presetNode) => _parseIdentifierLike(presetNode, "Preset name"));

    return new Configuration(
        reporter: reporter,
        pubServePort: pubServePort,
        concurrency: concurrency,
        platforms: platforms,
        paths: paths,
        filename: filename,
        chosenPresets: chosenPresets);
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

  /// Asserts that [field] is a map and runs [key] and [value] for each pair.
  ///
  /// Returns a map with the keys and values returned by [key] and [value]. Each
  /// of these defaults to asserting that the value is a string.
  Map _getMap(String field, {key(YamlNode keyNode),
      value(YamlNode valueNode)}) {
    var node = _getNode(field, "map", (value) => value is Map);
    if (node == null) return {};

    key ??= (keyNode) {
      _validate(keyNode, "$field keys must be strings.",
          (value) => value is String);

      return keyNode.value;
    };

    value ??= (valueNode) {
      _validate(valueNode, "$field values must be strings.",
          (value) => value is String);

      return valueNode.value;
    };

    return mapMap(node.nodes,
        key: (keyNode, _) => key(keyNode),
        value: (_, valueNode) => value(valueNode));
  }

  String _parseIdentifierLike(YamlNode node, String name) {
    _validate(node, "$name must be a string.", (value) => value is String);
    _validate(
        node,
        "$name must be an (optionally hyphenated) Dart identifier.",
        (value) => value.contains(anchoredHyphenatedIdentifier));
    return node.value;
  }

  /// Asserts that [node] is a string, passes its value to [parse], and returns
  /// the result.
  ///
  /// If [parse] throws a [FormatException], it's wrapped to include [node]'s
  /// span.
  _parseNode(YamlNode node, String name, parse(String value)) {
    _validate(node, "$name must be a string.", (value) => value is String);

    try {
      return parse(node.value);
    } on FormatException catch (error) {
      throw new SourceSpanFormatException(
          'Invalid $name: ${error.message}', node.span, _source);
    }
  }

  /// Asserts that [field] is a string, passes it to [parse], and returns the
  /// result.
  ///
  /// If [parse] throws a [FormatException], it's wrapped to include [field]'s
  /// span.
  _parseValue(String field, parse(String value)) {
    var node = _document.nodes[field];
    if (node == null) return null;
    return _parseNode(node, field, parse);
  }

  /// Parses a nested configuration document.
  ///
  /// [name] is the name of the field, which is used for error-handling.
  /// [runnerConfig] controls whether runner configuration is allowed in the
  /// nested configuration. It defaults to [_runnerConfig].
  Configuration _nestedConfig(YamlNode node, String name,
      {bool runnerConfig}) {
    if (node == null || node.value == null) return Configuration.empty;

    _validate(node, "$name must be a map.", (value) => value is Map);
    var loader = new _ConfigurationLoader(node, _source,
        runnerConfig: runnerConfig ?? _runnerConfig);
    return loader.load();
  }

  /// Throws an error if a field named [field] exists at this level.
  void _disallow(String field) {
    if (!_document.containsKey(field)) return;
    _error("$field isn't supported here.", field);
  }

  /// Throws a [SourceSpanFormatException] with [message] about [field].
  void _error(String message, String field) {
    throw new SourceSpanFormatException(
        message, _document.nodes[field].span, _source);
  }
}
