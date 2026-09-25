// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

final class _ActiveStandaloneSetup {
  final String url;
  final Isolate isolate;
  final SendPort commandPort;

  _ActiveStandaloneSetup({
    required this.url,
    required this.isolate,
    required this.commandPort,
  });
}

final _standaloneSetups = <String, Future<String>>{};
final _standaloneActiveSetups = <_ActiveStandaloneSetup>[];
Directory? _standaloneTempDir;

/// Executes [uri] as a standalone global setup hook in an isolate and returns
/// its result.
///
/// Used as a fallback when running tests directly (e.g. `dart test.dart`)
/// without `dart test`.
Future<Object?> standaloneGlobalSetup(Uri uri) async {
  final normalizedUrl = _normalizeStandaloneUrl(uri);
  final jsonString = await _standaloneSetups.putIfAbsent(
    normalizedUrl,
    () => _runStandaloneSetup(normalizedUrl),
  );
  return json.decode(jsonString);
}

Future<String> _runStandaloneSetup(String url) async {
  final scriptUri = Uri.parse(url);
  _standaloneTempDir ??= Directory.systemTemp.createTempSync(
    'global_setup_standalone_',
  );
  final bootstrapFile = File(
    p.join(
      _standaloneTempDir!.path,
      'bootstrap_${_standaloneSetups.length}.dart',
    ),
  );

  final safeScriptUri = scriptUri.toString().replaceAll(r'$', '%24');
  final bootstrapContent =
      '''
import 'dart:isolate';
import 'package:test_core/src/bootstrap/vm.dart';
import '$safeScriptUri' as test;

void main(List<String> args, SendPort sendPort) {
  internalBootstrapVmHook(() => test.setUp, args, sendPort);
}
''';

  bootstrapFile.writeAsStringSync(bootstrapContent);

  final responsePort = ReceivePort();
  final errorPort = ReceivePort();
  try {
    final isolate = await Isolate.spawnUri(
      bootstrapFile.uri,
      [],
      responsePort.sendPort,
      packageConfig: await Isolate.packageConfig,
      onError: errorPort.sendPort,
    );

    final completer = Completer<String>();

    final errorSub = errorPort.listen((errorAndStack) {
      final list = errorAndStack as List<Object?>;
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Global setup "$url" failed:\n${list[0]}\n${list[1]}'),
        );
      }
    });

    final responseSub = responsePort.listen((response) {
      if (response case {
        'success': true,
        'result': var result,
        'hasTearDown': bool hasTearDown,
      }) {
        if (hasTearDown) {
          final commandPort = response['commandPort'] as SendPort;
          _standaloneActiveSetups.add(
            _ActiveStandaloneSetup(
              url: url,
              isolate: isolate,
              commandPort: commandPort,
            ),
          );
        } else {
          isolate.kill();
        }
        if (!completer.isCompleted) completer.complete(json.encode(result));
      } else if (response case {
        'success': false,
        'error': var error,
        'stackTrace': var stack,
      }) {
        isolate.kill();
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(
              'Global setup "$url" failed:\n$error'
              '${stack != null && "$stack".isNotEmpty ? "\n$stack" : ""}',
            ),
          );
        }
      }
    });

    final result = await completer.future;
    await errorSub.cancel();
    await responseSub.cancel();
    return result;
  } finally {
    responsePort.close();
    errorPort.close();
  }
}

/// Executes all registered teardowns and cleans up isolates for standalone runs.
Future<void> closeStandaloneGlobalSetups() async {
  for (var active in _standaloneActiveSetups.reversed) {
    final replyPort = ReceivePort();
    try {
      active.commandPort.send([replyPort.sendPort, 'teardown']);
      final response =
          await replyPort.first.timeout(
                const Duration(seconds: 30),
                onTimeout: () => {
                  'success': false,
                  'error': 'Teardown timed out',
                },
              )
              as Map<Object?, Object?>;
      if (response['success'] != true) {
        stderr.writeln(
          'Global teardown for "${active.url}" failed: ${response["error"]}',
        );
        exitCode = 1;
      }
    } catch (error) {
      stderr.writeln('Global teardown for "${active.url}" failed: $error');
      exitCode = 1;
    } finally {
      replyPort.close();
      active.isolate.kill();
    }
  }
  _standaloneActiveSetups.clear();

  try {
    if (_standaloneTempDir != null && _standaloneTempDir!.existsSync()) {
      _standaloneTempDir!.deleteSync(recursive: true);
    }
  } on IOException {
    // Ignore cleanup error.
  }
  _standaloneTempDir = null;
}

String _normalizeStandaloneUrl(Uri uri) {
  String normalized;
  switch (uri.scheme) {
    case '':
      if (uri.hasAbsolutePath) {
        if (uri.hasQuery) {
          throw ArgumentError.value(
            uri,
            'uri',
            'root-relative URIs cannot have query parameters',
          );
        }
        if (Uri(
              path: uri.path.replaceFirst(RegExp('^/+'), ''),
            ).pathSegments.firstOrNull ==
            '..') {
          throw ArgumentError.value(
            uri,
            'uri',
            'root-relative URIs cannot reach outside the package directory',
          );
        }
        normalized = p.url.join(
          p.toUri(p.current).toString(),
          uri.pathSegments.join('/'),
        );
      } else {
        if (uri.hasQuery) {
          throw ArgumentError.value(
            uri,
            'uri',
            'relative URIs cannot have query parameters',
          );
        }
        final baseDir = p.url.dirname(Platform.script.toString());
        normalized = p.url.join(baseDir, uri.path);
      }
    case 'file':
      if (uri.hasQuery) {
        throw ArgumentError.value(
          uri,
          'uri',
          'file: URIs cannot have query parameters',
        );
      }
      normalized = uri.toString();
    case 'package':
      final resolvedUri = Isolate.resolvePackageUriSync(uri);
      if (resolvedUri == null) {
        throw ArgumentError.value(
          uri,
          'uri',
          'Could not resolve the package URI',
        );
      }
      normalized = resolvedUri.toString();
    default:
      normalized = uri.toString();
  }

  return Uri.parse(normalized).removeFragment().toString();
}
