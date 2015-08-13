// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.io;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../backend/operating_system.dart';
import '../runner/application_exception.dart';
import '../util/stream_queue.dart';
import '../utils.dart';

/// The ASCII code for a newline character.
const _newline = 0xA;

/// The ASCII code for a carriage return character.
const _carriageReturn = 0xD;

/// The root directory of the Dart SDK.
final String sdkDir = p.dirname(p.dirname(Platform.resolvedExecutable));

/// The version of the Dart SDK currently in use.
final Version _sdkVersion = new Version.parse(
    new File(p.join(sdkDir, 'version'))
        .readAsStringSync().trim());

/// Returns the current operating system.
final OperatingSystem currentOS = (() {
  var name = Platform.operatingSystem;
  var os = OperatingSystem.findByIoName(name);
  if (os != null) return os;

  throw new UnsupportedError('Unsupported operating system "$name".');
})();

/// A queue of lines of standard input.
final stdinLines = new StreamQueue(
    UTF8.decoder.fuse(const LineSplitter()).bind(stdin));

/// The root directory below which to nest temporary directories created by the
/// test runner.
///
/// This is configurable so that the test code can validate that the runner
/// cleans up after itself fully.
final _tempDir = Platform.environment.containsKey("_UNITTEST_TEMP_DIR")
    ? Platform.environment["_UNITTEST_TEMP_DIR"]
    : Directory.systemTemp.path;

/// The path to the `lib` directory of the `test` package.
String libDir({String packageRoot}) {
  var pathToIo = libraryPath(#test.util.io, packageRoot: packageRoot);
  return p.dirname(p.dirname(p.dirname(pathToIo)));
}

// TODO(nweiz): Make this check [stdioType] once that works within "pub run".
/// Whether "special" strings such as Unicode characters or color escapes are
/// safe to use.
///
/// On Windows or when not printing to a terminal, only printable ASCII
/// characters should be used.
bool get canUseSpecialChars =>
    Platform.operatingSystem != 'windows' &&
    Platform.environment["_UNITTEST_USE_COLOR"] != "false";

/// Creates a temporary directory and returns its path.
String createTempDir() =>
    new Directory(_tempDir).createTempSync('dart_test_').path;

/// Creates a temporary directory and passes its path to [fn].
///
/// Once the [Future] returned by [fn] completes, the temporary directory and
/// all its contents are deleted. [fn] can also return `null`, in which case
/// the temporary directory is deleted immediately afterwards.
///
/// Returns a future that completes to the value that the future returned from
/// [fn] completes to.
Future withTempDir(Future fn(String path)) {
  return new Future.sync(() {
    var tempDir = createTempDir();
    return new Future.sync(() => fn(tempDir))
        .whenComplete(() => new Directory(tempDir).deleteSync(recursive: true));
  });
}

/// Return a transformation of [input] with all null bytes removed.
///
/// This works around the combination of issue 23295 and 22667 by removing null
/// bytes. This workaround can be removed when either of those are fixed in the
/// oldest supported SDK.
///
/// It also somewhat works around issue 23303 by removing any carriage returns
/// that are followed by newlines, to ensure that carriage returns aren't
/// doubled up in the output. This can be removed when the issue is fixed in the
/// oldest supported SDk.
Stream<List<int>> sanitizeForWindows(Stream<List<int>> input) {
  if (!Platform.isWindows) return input;

  return input.map((list) {
    var previous;
    return list.reversed.where((byte) {
      if (byte == 0) return false;
      if (byte == _carriageReturn && previous == _newline) return false;
      previous = byte;
      return true;
    }).toList().reversed.toList();
  });
}

/// Print a warning containing [message].
///
/// This automatically wraps lines if they get too long. If [color] is passed,
/// it controls whether the warning header is color; otherwise, it defaults to
/// [canUseSpecialChars].
void warn(String message, {bool color}) {
  if (color == null) color = canUseSpecialChars;
  var header = color
      ? "\u001b[33mWarning:\u001b[0m"
      : "Warning:";
  stderr.writeln(wordWrap("$header $message\n"));
}

/// Creates a URL string for [address]:[port].
///
/// Handles properly formatting IPv6 addresses.
Uri baseUrlForAddress(InternetAddress address, int port) {
  if (address.isLoopback) {
    return new Uri(scheme: "http", host: "localhost", port: port);
  }

  // IPv6 addresses in URLs need to be enclosed in square brackets to avoid
  // URL ambiguity with the ":" in the address.
  if (address.type == InternetAddressType.IP_V6) {
    return new Uri(scheme: "http", host: "[${address.address}]", port: port);
  }

  return new Uri(scheme: "http", host: address.address, port: port);
}

/// Returns the package root at [root].
///
/// If [override] is passed, that's used. If the package root doesn't exist, an
/// [ApplicationException] is thrown.
String packageRootFor(String root, [String override]) {
  if (root == null) root = p.current;
  var packageRoot = override == null ? p.join(root, 'packages') : override;

  if (!new Directory(packageRoot).existsSync()) {
    throw new ApplicationException(
        "Directory ${p.prettyUri(p.toUri(packageRoot))} does not exist.");
  }

  return packageRoot;
}

/// The library name must be globally unique, or the wrong library path may be
/// returned.
String libraryPath(Symbol libraryName, {String packageRoot}) {
  var lib = currentMirrorSystem().findLibrary(libraryName);
  if (lib.uri.scheme != 'package') return p.fromUri(lib.uri);

  // TODO(nweiz): is there a way to avoid assuming this is being run next to a
  // packages directory?.
  if (packageRoot == null) packageRoot = p.absolute('packages');
  return p.join(packageRoot, p.fromUri(lib.uri.path));
}

/// Repeatedly finds a probably-unused port on localhost and passes it to
/// [tryPort] until it binds successfully.
///
/// [tryPort] should return a non-`null` value or a Future completing to a
/// non-`null` value once it binds successfully. This value will be returned
/// by [getUnusedPort] in turn.
///
/// This is necessary for ensuring that our port binding isn't flaky for
/// applications that don't print out the bound port.
Future getUnusedPort(tryPort(int port)) {
  var value;
  return Future.doWhile(() async {
    value = await tryPort(await getUnsafeUnusedPort());
    return value == null;
  }).then((_) => value);
}

/// Returns a port that is probably, but not definitely, not in use.
///
/// This has a built-in race condition: another process may bind this port at
/// any time after this call has returned. If at all possible, callers should
/// use [getUnusedPort] instead.
Future<int> getUnsafeUnusedPort() async {
  var socket = await RawServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  var port = socket.port;
  await socket.close();
  return port;
}
