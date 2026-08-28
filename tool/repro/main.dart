// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

extension<T> on Stream<T> {
  Future<T> get fastFirst {
    final completer = Completer<T>();
    final subscription = listen(
      completer.complete,
      onError: completer.completeError,
    );
    return completer.future..whenComplete(subscription.cancel);
  }
}

Future<void> runScenario(
  String name,
  Future<void> Function(Directory tempDir, String socketPath) fn,
) async {
  print('\n=== Scenario: $name ===');
  var tempDir = Directory.systemTemp.createTempSync('repro_');
  var socketPath = p.join(tempDir.path, 'socket.sock');
  var sw = Stopwatch()..start();
  try {
    await fn(tempDir, socketPath).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        print('FAILED (TIMEOUT after 8s) in $name');
        throw TimeoutException('Timed out after 8s', const Duration(seconds: 8));
      },
    );
    print('PASSED ($name) in ${sw.elapsedMilliseconds}ms');
  } catch (e) {
    print('CAUGHT: $e');
  } finally {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

void main() async {
  print('Running reproduction test on OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  print('Dart SDK: ${Platform.version}');
  var clientScript = p.join(p.dirname(Platform.script.toFilePath()), 'client.dart');
  var aotRuntime = p.join(
    p.dirname(Platform.resolvedExecutable),
    Platform.isWindows ? 'dartaotruntime.exe' : 'dartaotruntime',
  );

  // Precompile client to AOT snapshot once
  var globalTempDir = Directory.systemTemp.createTempSync('global_aot_');
  var aotClientPath = p.join(globalTempDir.path, 'client.aot');
  print('Compiling client.dart to AOT snapshot...');
  var compileResult = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'aot-snapshot',
    clientScript,
    '-o',
    aotClientPath,
  ]);
  if (compileResult.exitCode != 0) {
    print('AOT compilation failed:\n${compileResult.stderr}');
    exit(1);
  }
  print('AOT snapshot ready at $aotClientPath');

  // Scenario 9: 4 concurrent AOT suites with serverSocket.first (EXPECTED: HANGS on Windows)
  await runScenario('9. 4 concurrent AOT suites, serverSocket.first', (tempDir, socketPath) async {
    var futures = <Future<void>>[];
    for (var i = 0; i < 4; i++) {
      var sPath = p.join(tempDir.path, 'socket_$i.sock');
      futures.add(() async {
        var server = await ServerSocket.bind(
          InternetAddress(sPath, type: InternetAddressType.unix),
          0,
        );
        var firstFuture = server.first;
        var proc = await Process.start(
          aotRuntime,
          [aotClientPath, sPath, 'handshake'],
          mode: ProcessStartMode.inheritStdio,
        );
        var serverSide = await firstFuture;
        serverSide.destroy();
        proc.kill();
        await server.close();
      }());
    }
    await Future.wait(futures);
  });

  // Scenario 9b: 4 concurrent AOT suites with fastFirst (EXPECTED: PASSES on Windows)
  await runScenario('9b. 4 concurrent AOT suites, serverSocket.fastFirst', (tempDir, socketPath) async {
    var futures = <Future<void>>[];
    for (var i = 0; i < 4; i++) {
      var sPath = p.join(tempDir.path, 'socket_fast_$i.sock');
      futures.add(() async {
        var server = await ServerSocket.bind(
          InternetAddress(sPath, type: InternetAddressType.unix),
          0,
        );
        var fastFirstFuture = server.fastFirst;
        var proc = await Process.start(
          aotRuntime,
          [aotClientPath, sPath, 'handshake'],
          mode: ProcessStartMode.inheritStdio,
        );
        var serverSide = await fastFirstFuture;
        serverSide.destroy();
        proc.kill();
        await server.close();
      }());
    }
    await Future.wait(futures);
  });

  try {
    globalTempDir.deleteSync(recursive: true);
  } catch (_) {}

  print('\n=== All Scenarios Complete ===');
  exit(0);
}
