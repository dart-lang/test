// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';
import 'package:test_api/backend.dart' show RemoteException;
import 'package:test_api/src/backend/suite.dart'; // ignore: implementation_imports

import '../util/package_config.dart';
import 'application_exception.dart';
import 'loader.dart';

final class _ActiveSetup {
  final String url;
  final Isolate isolate;
  final SendPort commandPort;

  _ActiveSetup({
    required this.url,
    required this.isolate,
    required this.commandPort,
  });
}

/// Manages the lifecycle, caching, and execution of global setup hooks.
final class GlobalSetupManager {
  static GlobalSetupManager? current;

  final Loader _loader;
  final _setups = <String, Future<Object?>>{};
  final _activeSetups = <_ActiveSetup>[];
  final _closeMemo = AsyncMemoizer<void>();

  GlobalSetupManager(this._loader);

  StreamChannel<Object?> get(String rawUrl, Suite suite) {
    return StreamChannelCompleter.fromFuture(() async {
      try {
        final normalizedUrl = _normalizeUrl(rawUrl, suite);
        final resultFuture = _setups.putIfAbsent(
          normalizedUrl,
          () => _runSetup(normalizedUrl),
        );
        final result = await resultFuture;
        return StreamChannel<Object?>.withGuarantees(
          Stream.value({'type': 'data', 'data': result}),
          NullStreamSink<Object?>(),
        );
      } catch (error, stackTrace) {
        return StreamChannel<Object?>.withGuarantees(
          Stream.value({
            'type': 'error',
            'error': RemoteException.serialize(error, stackTrace),
          }),
          NullStreamSink<Object?>(),
        );
      }
    }());
  }

  Future<Object?> _runSetup(String url) async {
    final responsePort = ReceivePort();
    final errorPort = ReceivePort();
    try {
      final scriptPath = Uri.parse(url).toFilePath();
      final dillUri = await _loader.compileHook(scriptPath);
      final isolate = await Isolate.spawnUri(
        dillUri,
        [],
        responsePort.sendPort,
        packageConfig: await packageConfigUri,
        onError: errorPort.sendPort,
      );

      final completer = Completer<Object?>();

      final errorSub = errorPort.listen((errorAndStack) {
        final list = errorAndStack as List<Object?>;
        if (!completer.isCompleted) {
          completer.completeError(
            ApplicationException(
              'Global setup "$url" failed:\n${list[0]}\n${list[1]}',
            ),
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
            final commandPort = (response as Map)['commandPort'] ;
            _activeSetups.add(
              _ActiveSetup(
                url: url,
                isolate: isolate,
                commandPort: commandPort,
              ),
            );
          } else {
            isolate.kill();
          }
          if (!completer.isCompleted) completer.complete(result);
        } else if (response case {
          'success': false,
          'error': var error,
          'stackTrace': var stack,
        }) {
          isolate.kill();
          if (!completer.isCompleted) {
            completer.completeError(
              ApplicationException(
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

  Future<void> close() => _closeMemo.runOnce(() async {
    for (var active in _activeSetups.reversed) {
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
    _activeSetups.clear();
  });

  String _normalizeUrl(String url, Suite suite) {
    final parsedUri = Uri.parse(url);

    String normalized;
    switch (parsedUri.scheme) {
      case '':
        if (parsedUri.hasAbsolutePath) {
          if (parsedUri.hasQuery) {
            throw ArgumentError.value(
              url,
              'uri',
              'root-relative URIs cannot have query parameters',
            );
          }
          normalized = p.url.join(
            p.toUri(p.current).toString(),
            parsedUri.path.substring(1),
          );
        } else {
          if (parsedUri.hasQuery) {
            throw ArgumentError.value(
              url,
              'uri',
              'relative URIs cannot have query parameters',
            );
          }
          var suitePath = suite.path!;
          normalized = p.url.join(
            p.url.dirname(p.toUri(p.absolute(suitePath)).toString()),
            parsedUri.path,
          );
        }
      case 'file':
        if (parsedUri.hasQuery) {
          throw ArgumentError.value(
            url,
            'uri',
            'file: URIs cannot have query parameters',
          );
        }
        normalized = parsedUri.toString();
      case 'package':
        final resolvedUri = Isolate.resolvePackageUriSync(parsedUri);
        if (resolvedUri == null) {
          throw ArgumentError.value(
            url,
            'uri',
            'Could not resolve the package URI',
          );
        }
        normalized = resolvedUri.toString();
      default:
        normalized = url;
    }

    return Uri.parse(normalized).removeFragment().toString();
  }
}
