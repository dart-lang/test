// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
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

final _standaloneSetups = <String, Future<Object?>>{};
final _standaloneActiveSetups = <_ActiveStandaloneSetup>[];
Directory? _standaloneTempDir;

/// Executes [uri] as a standalone global setup hook in an isolate and returns
/// its result.
///
/// Used as a fallback when running tests directly (e.g. `dart test.dart`)
/// without `dart test`.
Future<Object?> standaloneGlobalSetup(Uri uri) async {
  final normalizedUrl = await _normalizeStandaloneUrl(uri);
  return _standaloneSetups.putIfAbsent(
    normalizedUrl,
    () => _runStandaloneSetup(normalizedUrl),
  );
}

Future<Object?> _runStandaloneSetup(String url) async {
  final scriptUri = Uri.parse(url);
  _standaloneTempDir ??= await Directory.systemTemp.createTemp(
    'global_setup_standalone_',
  );
  final bootstrapFile = File(
    p.join(
      _standaloneTempDir!.path,
      'bootstrap_${_standaloneSetups.length}.dart',
    ),
  );

  final bootstrapContent =
      '''
import 'dart:isolate';
import 'package:test_core/src/bootstrap/vm.dart';
import '$scriptUri' as test;

void main(List<String> args, SendPort sendPort) {
  internalBootstrapVmHook(() => test.main, args, sendPort);
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

    final completer = Completer<Object?>();

    final errorSub = errorPort.listen((errorAndStack) {
      final list = errorAndStack as List<Object?>;
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Global setup "$url" failed:\n${list[0]}\n${list[1]}'),
        );
      }
    });

    final responseSub = responsePort.listen((response) {
      final map = response as Map<Object?, Object?>;
      if (map['success'] == true) {
        if (map['hasTearDown'] == true && map['commandPort'] is SendPort) {
          _standaloneActiveSetups.add(
            _ActiveStandaloneSetup(
              url: url,
              isolate: isolate,
              commandPort: map['commandPort'] as SendPort,
            ),
          );
        } else {
          isolate.kill();
        }
        if (!completer.isCompleted) completer.complete(map['result']);
      } else {
        isolate.kill();
        if (!completer.isCompleted) {
          final error = map['error'];
          final stack = map['stackTrace'];
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

/// Executes all registered teardowns and cleans up isolates for standalone
/// runs.
Future<void> closeStandaloneGlobalSetups() async {
  for (var active in _standaloneActiveSetups) {
    final replyPort = ReceivePort();
    try {
      active.commandPort.send({
        'command': 'teardown',
        'replyPort': replyPort.sendPort,
      });
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

Future<String> _normalizeStandaloneUrl(Uri uri) async {
  String normalized;
  switch (uri.scheme) {
    case '':
      var isRootRelative = uri.path.startsWith('/');
      if (isRootRelative) {
        normalized = p.url.join(
          p.toUri(p.current).toString(),
          uri.path.substring(1),
        );
      } else {
        // Relative to current directory/entrypoint
        normalized = p.url.join(p.toUri(p.current).toString(), uri.toString());
      }
    case 'package':
      final resolvedUri = await Isolate.resolvePackageUri(uri);
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
  return Uri.parse(normalized).normalizePath().toString();
}
