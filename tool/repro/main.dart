// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
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

  // Scenario 1: Same process client, serverSocket.first
  await runScenario('1. Same process, serverSocket.first', (tempDir, socketPath) async {
    var server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var firstFuture = server.first;
    var client = await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var serverSide = await firstFuture;
    print('Received server-side socket: $serverSide');
    client.destroy();
    serverSide.destroy();
    await server.close();
  });

  // Scenario 2: Same process client, explicit await sub.cancel()
  await runScenario('2. Same process, explicit await sub.cancel()', (tempDir, socketPath) async {
    var server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var completer = Completer<Socket>();
    late StreamSubscription<Socket> sub;
    sub = server.listen((s) async {
      print('Calling await sub.cancel()...');
      var cancelFuture = sub.cancel();
      print('sub.cancel() returned $cancelFuture, awaiting...');
      await cancelFuture;
      print('await sub.cancel() finished!');
      completer.complete(s);
    });
    var client = await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var serverSide = await completer.future;
    client.destroy();
    serverSide.destroy();
    await server.close();
  });

  // Scenario 3: Subprocess client (ProcessStartMode.normal), serverSocket.first
  await runScenario('3. Subprocess (normal mode), serverSocket.first', (tempDir, socketPath) async {
    var server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var firstFuture = server.first;
    var proc = await Process.start(
      Platform.resolvedExecutable,
      [clientScript, socketPath, 'stay_alive'],
    );
    proc.stdout.listen(stdout.add);
    proc.stderr.listen(stderr.add);

    print('Awaiting server.first...');
    var serverSide = await firstFuture;
    print('server.first completed with: $serverSide');
    serverSide.destroy();
    proc.kill();
    await server.close();
  });

  // Scenario 4: Subprocess client (ProcessStartMode.inheritStdio), serverSocket.first
  await runScenario('4. Subprocess (inheritStdio mode), serverSocket.first', (tempDir, socketPath) async {
    var server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var firstFuture = server.first;
    var proc = await Process.start(
      Platform.resolvedExecutable,
      [clientScript, socketPath, 'stay_alive'],
      mode: ProcessStartMode.inheritStdio,
    );

    print('Awaiting server.first...');
    var serverSide = await firstFuture;
    print('server.first completed with: $serverSide');
    serverSide.destroy();
    proc.kill();
    await server.close();
  });

  // Scenario 5: Background process running during bind and serverSocket.first
  await runScenario('5. Background process running, serverSocket.first', (tempDir, socketPath) async {
    // Start a background process that keeps running
    var bgProc = await Process.start(
      Platform.resolvedExecutable,
      [clientScript, socketPath, 'stay_alive'], // Will fail or wait
      mode: ProcessStartMode.inheritStdio,
    );

    var server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var firstFuture = server.first;
    var proc = await Process.start(
      Platform.resolvedExecutable,
      [clientScript, socketPath, 'stay_alive'],
      mode: ProcessStartMode.inheritStdio,
    );

    print('Awaiting server.first with background process active...');
    var serverSide = await firstFuture;
    print('server.first completed with: $serverSide');
    serverSide.destroy();
    proc.kill();
    bgProc.kill();
    await server.close();
  });

  // Scenario 6: AOT-snapshot compiled client with inheritStdio (exactly matching VMPlatform.load)
  await runScenario('6. AOT client with inheritStdio, serverSocket.first', (tempDir, socketPath) async {
    var aotPath = p.join(tempDir.path, 'client.aot');
    var compileResult = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'aot-snapshot',
      clientScript,
      '-o',
      aotPath,
    ]);
    if (compileResult.exitCode != 0) {
      print('AOT compilation failed:\n${compileResult.stderr}');
      return;
    }
    var aotRuntime = p.join(
      p.dirname(Platform.resolvedExecutable),
      Platform.isWindows ? 'dartaotruntime.exe' : 'dartaotruntime',
    );

    var server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var firstFuture = server.first;
    var proc = await Process.start(
      aotRuntime,
      [aotPath, socketPath, 'stay_alive'],
      mode: ProcessStartMode.inheritStdio,
    );

    print('Awaiting server.first with AOT client...');
    var serverSide = await firstFuture;
    print('server.first completed with: $serverSide');
    serverSide.destroy();
    proc.kill();
    await server.close();
  });

  // Scenario 7: AOT client with fastFirst (verifying resolution)
  await runScenario('7. AOT client with inheritStdio, serverSocket.fastFirst', (tempDir, socketPath) async {
    var aotPath = p.join(tempDir.path, 'client.aot');
    var compileResult = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'aot-snapshot',
      clientScript,
      '-o',
      aotPath,
    ]);
    if (compileResult.exitCode != 0) {
      print('AOT compilation failed:\n${compileResult.stderr}');
      return;
    }
    var aotRuntime = p.join(
      p.dirname(Platform.resolvedExecutable),
      Platform.isWindows ? 'dartaotruntime.exe' : 'dartaotruntime',
    );

    var server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var fastFirstFuture = server.fastFirst;
    var proc = await Process.start(
      aotRuntime,
      [aotPath, socketPath, 'stay_alive'],
      mode: ProcessStartMode.inheritStdio,
    );

    print('Awaiting server.fastFirst with AOT client...');
    var serverSide = await fastFirstFuture;
    print('server.fastFirst completed with: $serverSide');
    serverSide.destroy();
    proc.kill();
    await server.close();
  });

  print('\n=== All Scenarios Complete ===');
}
