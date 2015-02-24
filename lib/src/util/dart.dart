// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.util.dart;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'isolate_wrapper.dart';
import 'remote_exception.dart';

/// Runs [code] in an isolate.
///
/// [code] should be the contents of a Dart entrypoint. It may contain imports;
/// they will be resolved in the same context as the host isolate. [message] is
/// passed to the [main] method of the code being run; the caller is responsible
/// for using this to establish communication with the isolate.
///
/// [packageRoot] controls the package root of the isolate. It may be either a
/// [String] or a [Uri].
Future<Isolate> runInIsolate(String code, message, {packageRoot}) {
  // TODO(nweiz): load code from a local server rather than from a file.
  var dir = Directory.systemTemp.createTempSync().path;
  var dartPath = p.join(dir, 'runInIsolate.dart');
  new File(dartPath).writeAsStringSync(code);
  var port = new ReceivePort();
  return Isolate.spawn(_isolateBuffer, {
    'replyTo': port.sendPort,
    'uri': p.toUri(dartPath).toString(),
    'packageRoot': packageRoot == null ? null : packageRoot.toString(),
    'message': message
  }).then((isolate) {
    return port.first.then((response) {
      if (response['type'] != 'error') return isolate;
      if (supportsIsolateKill) isolate.kill();
      var asyncError = RemoteException.deserialize(response['error']);
      return new Future.error(asyncError.error, asyncError.stackTrace);
    });
  }).catchError((error) {
    new Directory(dir).deleteSync(recursive: true);
    throw error;
  }).then((isolate) {
    return new IsolateWrapper(isolate,
        () => new Directory(dir).deleteSync(recursive: true));
  });
}

// TODO(nweiz): remove this when issue 12617 is fixed.
/// A function used as a buffer between the host isolate and [spawnUri].
///
/// [spawnUri] synchronously loads the file and its imports, which can deadlock
/// the host isolate if there's an HTTP import pointing at a server in the host.
/// Adding an additional isolate in the middle works around this.
void _isolateBuffer(message) {
  var replyTo = message['replyTo'];
  var packageRoot = message['packageRoot'];
  if (packageRoot != null) packageRoot = Uri.parse(packageRoot);
  Isolate.spawnUri(Uri.parse(message['uri']), [], message['message'],
          packageRoot: packageRoot)
      .then((_) => replyTo.send({'type': 'success'}))
      .catchError((error, stackTrace) {
    replyTo.send({
      'type': 'error',
      'error': RemoteException.serialize(error, stackTrace)
    });
  });
}
