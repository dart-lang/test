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
      final path = await importCheck.findPathToPackage(
        startUri: .parse('package:test/test.dart'),
        targetPackage: 'analyzer',
      );
      expect(
        path,
        isNull,
        reason:
            'package:test/test.dart must not transitively import '
            'package:analyzer.\n'
            'Found path:\n'
            '${path?.map((u) => '  -> $u').join('\n')}',
      );
    });
  });
}

Uri _testApiLibrary(String path) => .parse('package:test_api/$path');

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

    final visited = <Uri>{};
    final queue = Queue<Uri>()..addAll(entryPoints);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (!visited.add(current)) continue;

      final imports = await _findImports(current);
      final samePackageImports = imports
          .where(
            (u) =>
                u.isScheme('package') &&
                u.pathSegments.isNotEmpty &&
                u.pathSegments.first == package,
          )
          .toSet();

      yield _Source(current, samePackageImports);

      for (final import in samePackageImports) {
        if (!visited.contains(import)) {
          queue.add(import);
        }
      }
    }
  }

  Future<List<Uri>?> findPathToPackage({
    required Uri startUri,
    required String targetPackage,
  }) async {
    var queue = Queue<List<Uri>>();
    queue.add([startUri]);

    var visited = {startUri};

    while (queue.isNotEmpty) {
      var path = queue.removeFirst();
      var current = path.last;

      if (current.isScheme('package') &&
          current.pathSegments.isNotEmpty &&
          current.pathSegments.first == targetPackage) {
        return path;
      }

      List<Uri> neighbors;
      try {
        neighbors = await _findImports(current);
      } catch (e) {
        continue;
      }

      for (var neighbor in neighbors) {
        if (!visited.add(neighbor)) continue;

        var newPath = [...path, neighbor];
        queue.add(newPath);

        if (neighbor.isScheme('package') &&
            neighbor.pathSegments.isNotEmpty &&
            neighbor.pathSegments.first == targetPackage) {
          return newPath;
        }
      }
    }

    return null;
  }

  Future<List<Uri>> _findImports(Uri from) async {
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

          bool? conditionValue;
          if (name == 'dart.library.io' ||
              name == 'dart.library.cli' ||
              name == 'dart.library.isolate') {
            conditionValue = true;
          } else if (name == 'dart.library.html' ||
              name == 'dart.library.js' ||
              name == 'dart.library.js_interop') {
            conditionValue = false;
          }

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

    return uris
        .where((u) => !u.isScheme('dart') && !u.isScheme('dart-mac'))
        .toList();
  }
}

class _Source {
  final Uri uri;
  final Set<Uri> imports;

  _Source(this.uri, this.imports);
}
