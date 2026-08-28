// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

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

Future<bool> runScenario({
  required String name,
  required Future<void> Function(
          Directory tempDir, String aotRuntime, String aotClientPath)
      fn,
  required String aotRuntime,
  required String aotClientPath,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final line = '=' * 70;
  print('\n$line\nScenario: $name\n$line');
  var tempDir = Directory.systemTemp.createTempSync('repro_');
  var sw = Stopwatch()..start();
  var timedOut = false;
  try {
    await fn(tempDir, aotRuntime, aotClientPath).timeout(
      timeout,
      onTimeout: () {
        timedOut = true;
        print(
            '\n[RESULT] FAILED with TIMEOUT after ${timeout.inSeconds}s in: $name');
        throw TimeoutException(
            'Timed out after ${timeout.inSeconds}s', timeout);
      },
    );
    print('\n[RESULT] PASSED ($name) in ${sw.elapsedMilliseconds}ms');
    return true;
  } catch (e) {
    if (!timedOut) {
      print('\n[RESULT] CAUGHT ERROR in ($name): $e');
    }
    return false;
  } finally {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

void main() async {
  final line = '=' * 70;
  print('$line\nRunning standalone reproduction test');
  print('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  print('Dart SDK: ${Platform.version}\n$line');

  var sep = Platform.pathSeparator;
  var scriptPath = Platform.script.toFilePath();
  var reproDir = scriptPath.substring(0, scriptPath.lastIndexOf(sep));
  var clientScript = '$reproDir${sep}client.dart';
  var binDir = Platform.resolvedExecutable.substring(
    0,
    Platform.resolvedExecutable.lastIndexOf(sep),
  );
  var aotRuntime =
      '$binDir$sep${Platform.isWindows ? 'dartaotruntime.exe' : 'dartaotruntime'}';

  var globalTempDir = Directory.systemTemp.createTempSync('global_aot_');
  var aotClientPath = '${globalTempDir.path}${sep}client.aot';
  print('Compiling client.dart to AOT snapshot...');
  var compileResult = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'aot-snapshot',
    clientScript,
    '-o',
    aotClientPath,
  ]);
  if (compileResult.exitCode != 0) {
    stderr.writeln('AOT compilation failed:\n${compileResult.stderr}');
    exit(1);
  }
  print('AOT snapshot ready at $aotClientPath\n');

  // Scenario 1: Sequential baseline with serverSocket.first
  await runScenario(
    name:
        '1. Sequential baseline (1 process at a time) with serverSocket.first',
    aotRuntime: aotRuntime,
    aotClientPath: aotClientPath,
    fn: (tempDir, runtime, clientAot) async {
      for (var i = 0; i < 2; i++) {
        var sPath = '${tempDir.path}${sep}socket_seq_$i.sock';
        var server = await ServerSocket.bind(
          InternetAddress(sPath, type: InternetAddressType.unix),
          0,
        );
        var firstFuture = server.first;
        var proc = await Process.start(
          runtime,
          [clientAot, sPath, '$i'],
          mode: ProcessStartMode.inheritStdio,
        );
        var serverSide = await firstFuture;
        print('[SERVER $i] serverSocket.first resolved successfully!');
        serverSide.destroy();
        proc.kill();
        await server.close();
      }
    },
  );

  // Scenario 2: 4 concurrent processes with serverSocket.first (EXPECTED: HANGS on Windows)
  var scenario2Passed = await runScenario(
    name:
        '2. 4 concurrent processes with serverSocket.first (SDK Stream.first deadlock)',
    aotRuntime: aotRuntime,
    aotClientPath: aotClientPath,
    fn: (tempDir, runtime, clientAot) async {
      var futures = <Future<void>>[];
      for (var i = 0; i < 4; i++) {
        var sPath = '${tempDir.path}${sep}socket_first_$i.sock';
        futures.add(() async {
          var server = await ServerSocket.bind(
            InternetAddress(sPath, type: InternetAddressType.unix),
            0,
          );
          print(
              '[SERVER $i] Bound ServerSocket. Awaiting serverSocket.first...');
          var firstFuture = server.first;
          var proc = await Process.start(
            runtime,
            [clientAot, sPath, '$i'],
            mode: ProcessStartMode.inheritStdio,
          );
          print('[SERVER $i] Spawned child process PID ${proc.pid}');
          var serverSide = await firstFuture;
          print('[SERVER $i] serverSocket.first RESOLVED!');
          serverSide.destroy();
          proc.kill();
          await server.close();
        }());
      }
      await Future.wait(futures);
    },
  );

  // Scenario 3: 4 concurrent processes with direct instrumentation of subscription.cancel()
  await runScenario(
    name:
        '3. 4 concurrent processes measuring subscription.cancel() completion',
    aotRuntime: aotRuntime,
    aotClientPath: aotClientPath,
    fn: (tempDir, runtime, clientAot) async {
      var futures = <Future<void>>[];
      for (var i = 0; i < 4; i++) {
        var sPath = '${tempDir.path}${sep}socket_cancel_$i.sock';
        futures.add(() async {
          var server = await ServerSocket.bind(
            InternetAddress(sPath, type: InternetAddressType.unix),
            0,
          );
          final completer = Completer<Socket>();
          late StreamSubscription<Socket> sub;
          sub = server.listen((socket) {
            print('[SERVER $i] Connection received from client!');
            completer.complete(socket);
            var swCancel = Stopwatch()..start();
            print('[SERVER $i] Calling sub.cancel()...');
            var cancelFuture = sub.cancel();
            cancelFuture.then((_) {
              print(
                  '[SERVER $i] sub.cancel() COMPLETED after ${swCancel.elapsedMilliseconds}ms');
            }).catchError((Object e) {
              print('[SERVER $i] sub.cancel() ERRORED: $e');
            });
          });

          var proc = await Process.start(
            runtime,
            [clientAot, sPath, '$i'],
            mode: ProcessStartMode.inheritStdio,
          );
          print('[SERVER $i] Spawned child process PID ${proc.pid}');
          var serverSide = await completer.future;
          print(
              '[SERVER $i] Server got socket via completer (without waiting for cancel)');
          serverSide.destroy();
          proc.kill();
          await server.close();
        }());
      }
      await Future.wait(futures);
    },
  );

  // Scenario 4: 4 concurrent processes with fastFirst (EXPECTED: PASSES on all platforms)
  var scenario4Passed = await runScenario(
    name: '4. 4 concurrent processes with fastFirst (Fix)',
    aotRuntime: aotRuntime,
    aotClientPath: aotClientPath,
    fn: (tempDir, runtime, clientAot) async {
      var futures = <Future<void>>[];
      for (var i = 0; i < 4; i++) {
        var sPath = '${tempDir.path}${sep}socket_fast_$i.sock';
        futures.add(() async {
          var server = await ServerSocket.bind(
            InternetAddress(sPath, type: InternetAddressType.unix),
            0,
          );
          print(
              '[SERVER $i] Bound ServerSocket. Awaiting serverSocket.fastFirst...');
          var fastFirstFuture = server.fastFirst;
          var proc = await Process.start(
            runtime,
            [clientAot, sPath, '$i'],
            mode: ProcessStartMode.inheritStdio,
          );
          print('[SERVER $i] Spawned child process PID ${proc.pid}');
          var serverSide = await fastFirstFuture;
          print('[SERVER $i] serverSocket.fastFirst RESOLVED!');
          serverSide.destroy();
          proc.kill();
          await server.close();
        }());
      }
      await Future.wait(futures);
    },
  );

  try {
    globalTempDir.deleteSync(recursive: true);
  } catch (_) {}

  print('\n$line\nSUMMARY:');
  print(
      'Scenario 2 (serverSocket.first): ${scenario2Passed ? "PASSED" : "FAILED (deadlock reproduced)"}');
  print(
      'Scenario 4 (serverSocket.fastFirst): ${scenario4Passed ? "PASSED" : "FAILED"}');
  print(line);

  if (Platform.isWindows && scenario2Passed) {
    stderr.writeln(
        'WARNING: Scenario 2 was expected to fail on Windows but passed!');
    exit(1);
  }
}
