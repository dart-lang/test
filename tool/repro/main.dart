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

  // Scenario 8: Client sends data (handshake) immediately with inheritStdio
  await runScenario('8. AOT client sending handshake, serverSocket.first', (tempDir, socketPath) async {
    var server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var firstFuture = server.first;
    var proc = await Process.start(
      aotRuntime,
      [aotClientPath, socketPath, 'handshake'],
      mode: ProcessStartMode.inheritStdio,
    );

    print('Awaiting server.first...');
    var serverSide = await firstFuture;
    print('server.first completed: $serverSide');
    serverSide.destroy();
    proc.kill();
    await server.close();
  });

  // Scenario 9: 4 concurrent AOT suites connecting at once
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

  // Scenario 10: Local HttpServer + WebSocket active, while AOT client connects
  await runScenario('10. HttpServer + WebSocket active, serverSocket.first', (tempDir, socketPath) async {
    var httpServer = await HttpServer.bind('localhost', 0);
    httpServer.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        var ws = await WebSocketTransformer.upgrade(request);
        ws.listen((_) {});
      } else {
        request.response.write('ok');
        await request.response.close();
      }
    });

    var wsClient = await WebSocket.connect('ws://localhost:${httpServer.port}');
    wsClient.add('ping');

    var server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    var firstFuture = server.first;
    var proc = await Process.start(
      aotRuntime,
      [aotClientPath, socketPath, 'handshake'],
      mode: ProcessStartMode.inheritStdio,
    );

    print('Awaiting server.first with active WebSocket...');
    var serverSide = await firstFuture;
    print('server.first completed: $serverSide');
    serverSide.destroy();
    proc.kill();
    await server.close();
    await wsClient.close();
    await httpServer.close(force: true);
  });

  // Find Chrome executable if available
  String? chromePath;
  if (Platform.isWindows) {
    for (var path in [
      Platform.environment['CHROME_EXECUTABLE'],
      r'C:\Program Files\Google\Chrome\Application\chrome.exe',
      r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    ]) {
      if (path != null && File(path).existsSync()) {
        chromePath = path;
        break;
      }
    }
  } else if (Platform.isLinux) {
    for (var path in ['/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium']) {
      if (File(path).existsSync()) {
        chromePath = path;
        break;
      }
    }
  }
  print('Detected Chrome executable: $chromePath');

  if (chromePath != null) {
    // Scenario 11: Chrome running headless in background, serverSocket.first
    await runScenario('11. Chrome running in background, serverSocket.first', (tempDir, socketPath) async {
      var chromeUserDataDir = p.join(tempDir.path, 'chrome_user_data');
      var chromeProc = await Process.start(chromePath!, [
        '--headless',
        '--disable-gpu',
        '--user-data-dir=$chromeUserDataDir',
        'about:blank',
      ]);

      var server = await ServerSocket.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      var firstFuture = server.first;
      var proc = await Process.start(
        aotRuntime,
        [aotClientPath, socketPath, 'handshake'],
        mode: ProcessStartMode.inheritStdio,
      );

      print('Awaiting server.first with Chrome running...');
      var serverSide = await firstFuture;
      print('server.first completed: $serverSide');
      serverSide.destroy();
      proc.kill();
      chromeProc.kill();
      await server.close();
    });

    // Scenario 12: Full BrowserPlatform simulation (HttpServer + Chrome connected + 4 AOT suites)
    await runScenario('12. Full simulation: HttpServer + Chrome connected + 4 AOT suites, serverSocket.first', (tempDir, socketPath) async {
      var httpServer = await HttpServer.bind('localhost', 0);
      var wsCompleter = Completer<WebSocket>();
      httpServer.listen((request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          var ws = await WebSocketTransformer.upgrade(request);
          if (!wsCompleter.isCompleted) wsCompleter.complete(ws);
          ws.listen((_) {});
        } else {
          request.response.headers.contentType = ContentType.html;
          request.response.write('''
            <html><body><script>
              var ws = new WebSocket("ws://localhost:${httpServer.port}");
              ws.onopen = function() {
                setInterval(function() { ws.send("heartbeat"); }, 100);
              };
            </script></body></html>
          ''');
          await request.response.close();
        }
      });

      var chromeUserDataDir = p.join(tempDir.path, 'chrome_user_data_12');
      var chromeProc = await Process.start(chromePath!, [
        '--headless',
        '--disable-gpu',
        '--user-data-dir=$chromeUserDataDir',
        'http://localhost:${httpServer.port}',
      ]);

      // Wait for Chrome to connect to WebSocket
      try {
        await wsCompleter.future.timeout(const Duration(seconds: 5));
        print('Chrome connected to server WebSocket!');
      } catch (e) {
        print('Chrome did not connect within 5s, proceeding anyway...');
      }

      // Now run 4 concurrent AOT suites with serverSocket.first
      var futures = <Future<void>>[];
      for (var i = 0; i < 4; i++) {
        var sPath = p.join(tempDir.path, 'socket_sim_$i.sock');
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

      chromeProc.kill();
      await httpServer.close(force: true);
    });
  }

  try {
    globalTempDir.deleteSync(recursive: true);
  } catch (_) {}

  print('\n=== All Scenarios Complete ===');
}
