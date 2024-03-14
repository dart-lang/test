// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:io/io.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

/// User-provided settings for invoking an executable.
class ExecutableSettings {
  /// Additional arguments to pass to the executable.
  final List<String> arguments;

  /// The path to the executable on Linux.
  ///
  /// This may be an absolute path or a basename, in which case it will be
  /// looked up on the system path. It may not be relative.
  final List<String> _linuxExecutables;

  /// The path to the executable on Mac OS.
  ///
  /// This may be an absolute path or a basename, in which case it will be
  /// looked up on the system path. It may not be relative.
  final List<String> _macOSExecutables;

  /// The path to the executable on Windows.
  ///
  /// This may be an absolute path; a basename, in which case it will be looked
  /// up on the system path; or a relative path, in which case it will be looked
  /// up relative to the paths in the `LOCALAPPDATA`, `PROGRAMFILES`, and
  /// `PROGRAMFILES(X64)` environment variables.
  final List<String> _windowsExecutables;

  /// The environment variable, if any, to use as an override for the default
  /// path.
  final String? _environmentOverride;

  /// The path to the executable for the current operating system.
  String get executable {
    if (_environmentOverride != null) {
      final envVariable = Platform.environment[_environmentOverride];
      if (envVariable != null) return envVariable;
    }

    if (Platform.isMacOS) {
      return _macOSExecutables.firstWhere((path) => File(path).existsSync());
    }
    if (!Platform.isWindows) {
      return _linuxExecutables.firstWhere((path) => File(path).existsSync());
    }
    for (var windowsExecutable in _windowsExecutables) {
      if (p.isAbsolute(windowsExecutable)) return windowsExecutable;
      if (p.basename(windowsExecutable) == windowsExecutable) {
        return windowsExecutable;
      }
    }

    var prefixes = [
      Platform.environment['LOCALAPPDATA'],
      Platform.environment['PROGRAMFILES'],
      Platform.environment['PROGRAMFILES(X86)']
    ];

    for (var prefix in prefixes) {
      if (prefix == null) continue;

      for (var windowsExecutable in _windowsExecutables) {
        var path = p.join(prefix, windowsExecutable);
        if (File(path).existsSync()) return path;
      }
    }

    // If we can't find a path that works, return one that doesn't. This will
    // cause an "executable not found" error to surface.
    return p.join(
        prefixes.firstWhere((prefix) => prefix != null, orElse: () => '.')!,
        _windowsExecutables.first);
  }

  /// Whether to invoke the browser in headless mode.
  ///
  /// This is currently only supported by Chrome.
  bool get headless => _headless ?? true;
  final bool? _headless;

  /// Parses settings from a user-provided YAML mapping.
  factory ExecutableSettings.parse(YamlMap settings) {
    List<String>? arguments;
    var argumentsNode = settings.nodes['arguments'];
    if (argumentsNode != null) {
      var value = argumentsNode.value;
      if (value is String) {
        try {
          arguments = shellSplit(value);
        } on FormatException catch (error) {
          throw SourceSpanFormatException(error.message, argumentsNode.span);
        }
      } else {
        throw SourceSpanFormatException(
            'Must be a string.', argumentsNode.span);
      }
    }

    final linuxExecutables = <String>[];
    final macOSExecutables = <String>[];
    final windowsExecutables = <String>[];
    var executableNode = settings.nodes['executable'];
    if (executableNode != null) {
      var value = executableNode.value;
      if (value is String) {
        // Don't check this on Windows because people may want to set relative
        // paths in their global config.
        if (!Platform.isWindows) {
          _assertNotRelative(executableNode as YamlScalar);
        }

        linuxExecutables.add(value);
        macOSExecutables.add(value);
        windowsExecutables.add(value);
      } else if (executableNode is YamlMap) {
        if (_getExecutable(executableNode.nodes['linux'])
            case final linuxExecutable?) {
          linuxExecutables.add(linuxExecutable);
        }
        if (_getExecutable(executableNode.nodes['mac_os'])
            case final macOSExecutable?) {
          macOSExecutables.add(macOSExecutable);
        }
        if (_getExecutable(executableNode.nodes['windows'], allowRelative: true)
            case final windowsExecutable?) {
          windowsExecutables.add(windowsExecutable);
        }
      } else {
        throw SourceSpanFormatException(
            'Must be a map or a string.', executableNode.span);
      }
    }

    var headless = true;
    var headlessNode = settings.nodes['headless'];
    if (headlessNode != null) {
      var value = headlessNode.value;
      if (value is bool) {
        headless = value;
      } else {
        throw SourceSpanFormatException(
            'Must be a boolean.', headlessNode.span);
      }
    }

    return ExecutableSettings(
        arguments: arguments,
        linuxExecutables: linuxExecutables,
        macOSExecutables: macOSExecutables,
        windowsExecutables: windowsExecutables,
        headless: headless);
  }

  /// Asserts that [executableNode] is a string or `null` and returns it.
  ///
  /// If [allowRelative] is `false` (the default), asserts that the value isn't
  /// a relative path.
  static String? _getExecutable(YamlNode? executableNode,
      {bool allowRelative = false}) {
    if (executableNode == null || executableNode.value == null) return null;
    if (executableNode.value is! String) {
      throw SourceSpanFormatException('Must be a string.', executableNode.span);
    }
    if (!allowRelative) _assertNotRelative(executableNode as YamlScalar);
    return executableNode.value as String;
  }

  /// Throws a [SourceSpanFormatException] if [executableNode]'s value is a
  /// relative POSIX path that's not just a plain basename.
  ///
  /// We loop up basenames on the PATH and we can resolve absolute paths, but we
  /// have no way of interpreting relative paths.
  static void _assertNotRelative(YamlScalar executableNode) {
    var executable = executableNode.value as String;
    if (!p.posix.isRelative(executable)) return;
    if (p.posix.basename(executable) == executable) return;

    throw SourceSpanFormatException(
        'Linux and Mac OS executables may not be relative paths.',
        executableNode.span);
  }

  ExecutableSettings(
      {Iterable<String>? arguments,
      List<String> linuxExecutables = const [],
      List<String> macOSExecutables = const [],
      List<String> windowsExecutables = const [],
      String? environmentOverride,
      bool? headless})
      : arguments = arguments == null ? const [] : List.unmodifiable(arguments),
        _linuxExecutables = linuxExecutables,
        _macOSExecutables = macOSExecutables,
        _windowsExecutables = windowsExecutables,
        _environmentOverride = environmentOverride,
        _headless = headless;

  /// Merges [this] with [other], with [other]'s settings taking priority.
  ///
  /// Executable paths are not merged, but overridden by [other] unless empty.
  ExecutableSettings merge(ExecutableSettings other) => ExecutableSettings(
        arguments: arguments.toList()..addAll(other.arguments),
        headless: other._headless ?? _headless,
        linuxExecutables: [
          if (other._linuxExecutables.isEmpty)
            ..._linuxExecutables
          else
            ...other._linuxExecutables,
        ],
        macOSExecutables: [
          if (other._macOSExecutables.isEmpty)
            ..._macOSExecutables
          else
            ...other._macOSExecutables,
        ],
        windowsExecutables: [
          if (other._windowsExecutables.isEmpty)
            ..._windowsExecutables
          else
            ...other._windowsExecutables,
        ],
      );
}
