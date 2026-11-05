// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm && !exe')
library;

import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late _ImportCheck importCheck;
  setUpAll(() async {
    importCheck = await .create();
  });

  group('test_api', () {
    test('backend must not import from other subdirectories', () async {
      final entryPoints = [
        _testApiLibrary('backend.dart'),
        ...await _ImportCheck.findEntrypointsUnder(
          _testApiLibrary('src/backend'),
        ),
      ];
      await for (final source in importCheck.transitiveSamePackageSources(
        entryPoints,
      )) {
        for (final import in source.imports) {
          expect(import.pathSegments.skip(1).take(2), [
            'src',
            'backend',
          ], reason: 'Invalid import from ${source.uri} : $import');
        }
      }
    });
  });

  group('test entrypoint', () {
    test('must not transitively import package:analyzer', () async {
      final path = await importCheck.findPath(
        startUri: .parse('package:test/test.dart'),
        platform: .vm,
        isTarget: (uri) => _isInPackage(uri, 'analyzer'),
      );
      expect(
        path,
        isNull,
        reason:
            'package:test/test.dart must not transitively import '
            'package:analyzer.\n'
            'Found path:\n'
            '${_formatPath(path)}',
      );
    });
  });

  group('web entrypoints', () {
    for (final entrypoint in [
      'package:test/expect.dart',
      'package:test/scaffolding.dart',
      'package:test/test.dart',
    ]) {
      test('$entrypoint must not transitively import VM-only libraries '
          'when compiled for the web', () async {
        final path = await importCheck.findPath(
          startUri: .parse(entrypoint),
          platform: .web,
          isTarget: (uri) =>
              uri.isScheme('dart') && _vmOnlyLibraries.contains(uri.path),
        );
        expect(
          path,
          isNull,
          reason:
              '$entrypoint must not transitively import a VM-only library '
              'when compiled for the web. Use a conditional import with a '
              'stub for platform-specific code.\n'
              'Found path:\n'
              '${_formatPath(path)}',
        );
      });
    }
  });
}

/// Core libraries which are not available when compiling for the web.
const _vmOnlyLibraries = {'cli', 'ffi', 'io', 'isolate', 'mirrors'};

Uri _testApiLibrary(String path) => .parse('package:test_api/$path');

bool _isInPackage(Uri uri, String package) =>
    uri.isScheme('package') &&
    uri.pathSegments.isNotEmpty &&
    uri.pathSegments.first == package;

String? _formatPath(List<Uri>? path) => path?.map((u) => '  -> $u').join('\n');

/// The platform used to resolve conditional imports.
enum _Platform {
  vm(
    available: {'cli', 'io', 'isolate'},
    unavailable: {'html', 'js', 'js_interop'},
  ),
  web(
    available: {'html', 'js', 'js_interop'},
    unavailable: {'cli', 'io', 'isolate'},
  );

  const _Platform({required this.available, required this.unavailable});

  /// Libraries for which a `dart.library.<name>` condition is `true`.
  final Set<String> available;

  /// Libraries for which a `dart.library.<name>` condition is `false`.
  final Set<String> unavailable;

  /// The value of the configuration condition [name] on this platform, or
  /// `null` if it is unknown.
  bool? evaluate(String name) {
    const prefix = 'dart.library.';
    if (!name.startsWith(prefix)) return null;
    final library = name.substring(prefix.length);
    if (available.contains(library)) return true;
    if (unavailable.contains(library)) return false;
    return null;
  }
}

class _ImportCheck {
  final PackageConfig _packageConfig;

  _ImportCheck._(this._packageConfig);

  static Future<_ImportCheck> create() async {
    final packageUri = await Isolate.resolvePackageUri(
      .parse('package:test_api/'),
    );
    final packageConfig = await findPackageConfig(.fromUri(packageUri!));
    if (packageConfig == null) {
      throw StateError('Could not find package_config.json.');
    }
    return ._(packageConfig);
  }

  static Future<Iterable<Uri>> findEntrypointsUnder(Uri uri) async {
    if (!uri.path.endsWith('/')) {
      uri = uri.replace(path: '${uri.path}/');
    }
    final directoryPath = p.fromUri(await Isolate.resolvePackageUri(uri));
    final directory = Directory(directoryPath);
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) {
          final relativePath = p.relative(f.path, from: directoryPath);
          final relativeUri = p.toUri(relativePath);
          return uri.resolveUri(relativeUri);
        });
  }

  Stream<_Source> transitiveSamePackageSources(
    Iterable<Uri> entryPoints,
  ) async* {
    assert(entryPoints.every((e) => e.scheme == 'package'));
    final package = entryPoints.first.pathSegments.first;
    assert(entryPoints.skip(1).every((e) => e.pathSegments.first == package));

    final queue = Queue<Uri>()..addAll(entryPoints);
    final seen = <Uri>{...entryPoints};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      final imports = await _findImports(current, .vm);
      final samePackageImports = imports
          .where((u) => _isInPackage(u, package))
          .toSet();

      yield _Source(current, samePackageImports);

      samePackageImports.where(seen.add).forEach(queue.add);
    }
  }

  /// Returns the shortest import path from [startUri] to a URI matching
  /// [isTarget], resolving conditional imports for [platform], or `null` if
  /// there is no such path.
  Future<List<Uri>?> findPath({
    required Uri startUri,
    required _Platform platform,
    required bool Function(Uri) isTarget,
  }) async {
    var queue = Queue<Uri>()..add(startUri);
    var parents = <Uri, Uri?>{startUri: null};

    List<Uri> reconstructPath(Uri end) => [
      for (Uri? current = end; current != null; current = parents[current])
        current,
    ].reversed.toList();

    while (queue.isNotEmpty) {
      var current = queue.removeFirst();

      if (isTarget(current)) return reconstructPath(current);
      if (!current.isScheme('package') && !current.isScheme('file')) continue;

      List<Uri> neighbors;
      try {
        neighbors = await _findImports(current, platform);
      } catch (e) {
        continue;
      }

      for (var neighbor in neighbors) {
        if (parents.containsKey(neighbor)) continue;
        parents[neighbor] = current;
        if (isTarget(neighbor)) return reconstructPath(neighbor);
        queue.add(neighbor);
      }
    }

    return null;
  }

  /// Returns the URIs directly imported, exported, or included as parts by
  /// [from], resolving conditional imports for [platform].
  ///
  /// Includes `dart:` URIs.
  Future<List<Uri>> _findImports(Uri from, _Platform platform) async {
    Uri? fileUri;
    if (from.isScheme('package')) {
      fileUri = _packageConfig.resolve(from);
    } else if (from.isScheme('file')) {
      fileUri = from;
    } else {
      throw StateError('Unsupported URI scheme: $from');
    }

    if (fileUri == null) {
      throw StateError('Could not resolve: $from');
    }

    final path = fileUri.toFilePath();
    final file = File(path);
    if (!file.existsSync()) return [];

    final parseResult = parseString(
      content: file.readAsStringSync(),
      path: path,
      throwIfDiagnostics: false,
    );

    final unit = parseResult.unit;
    var uris = <Uri>[];

    for (var directive in unit.directives) {
      if (directive is NamespaceDirective) {
        String? selectedUri;
        for (var config in directive.configurations) {
          var name = config.name.toSource();
          var value = config.value?.stringValue ?? 'true';

          var conditionValue = platform.evaluate(name);
          if (conditionValue != null && conditionValue.toString() == value) {
            selectedUri = config.uri.stringValue;
            break;
          }
        }
        selectedUri ??= directive.uri.stringValue;
        if (selectedUri != null) {
          uris.add(from.resolve(selectedUri));
        }
      } else if (directive is PartDirective) {
        if (directive.uri.stringValue != null) {
          uris.add(from.resolve(directive.uri.stringValue!));
        }
      }
    }

    return uris;
  }
}

class _Source {
  final Uri uri;
  final Set<Uri> imports;

  _Source(this.uri, this.imports);
}
