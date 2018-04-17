// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:core' as core;
import 'dart:core';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../backend/operating_system.dart';
import '../backend/runtime.dart';
import '../backend/suite_platform.dart';
import '../utils.dart';

/// The ASCII code for a newline character.
const _newline = 0xA;

/// The ASCII code for a carriage return character.
const _carriageReturn = 0xD;

/// The default line length for output when there isn't a terminal attached to
/// stdout.
const _defaultLineLength = 200;

/// Whether the test runner is running on Google-internal infrastructure.
final bool inGoogle = Platform.version.contains("(google3)");

/// The maximum line length for output.
final int lineLength = () {
  try {
    return stdout.terminalColumns;
  } on UnsupportedError {
    // This can throw an [UnsupportedError] if we're running in a JS context
    // where `dart:io` is unavaiable.
    return _defaultLineLength;
  } on StdoutException {
    return _defaultLineLength;
  }
}();

/// The root directory of the Dart SDK.
final String sdkDir = p.dirname(p.dirname(Platform.resolvedExecutable));

/// The version of the Dart SDK on which test is running.
final sdkVersion = new Version.parse(Platform.version.split(' ').first);

/// Returns the current operating system.
final OperatingSystem currentOS = (() {
  var name = Platform.operatingSystem;
  var os = OperatingSystem.findByIoName(name);
  if (os != null) return os;

  throw new UnsupportedError('Unsupported operating system "$name".');
})();

// TODO(nweiz): Make this `new SuitePlatform.current()` once we only support
// Dart 2 and we can import `dart:io` from within cross-platform libraries. See
// commit 4ffda6d2.
/// Returns a [SuitePlatform] with the given [runtime], and with [os] and
/// [inGoogle] determined automatically.
///
/// If [runtime] is a browser, this will set [os] to [OperatingSystem.none].
SuitePlatform currentPlatform(Runtime runtime) => new SuitePlatform(runtime,
    os: runtime.isBrowser ? OperatingSystem.none : currentOS,
    inGoogle: inGoogle);

/// A queue of lines of standard input.
final stdinLines = new StreamQueue(lineSplitter.bind(stdin));

/// Whether this is being run as a subprocess in the test package's own tests.
bool inTestTests = Platform.environment["_DART_TEST_TESTING"] == "true";

/// The root directory below which to nest temporary directories created by the
/// test runner.
///
/// This is configurable so that the test code can validate that the runner
/// cleans up after itself fully.
final _tempDir = Platform.environment.containsKey("_UNITTEST_TEMP_DIR")
    ? Platform.environment["_UNITTEST_TEMP_DIR"]
    : Directory.systemTemp.path;

// TODO(nweiz): Make this check [stdioType] once that works within "pub run".
/// Whether "special" strings such as Unicode characters or color escapes are
/// safe to use.
///
/// On Windows or when not printing to a terminal, only printable ASCII
/// characters should be used.
bool get canUseSpecialChars =>
    Platform.operatingSystem != 'windows' && !inTestTests;

/// Creates a temporary directory and returns its path.
String createTempDir() => new Directory(_tempDir)
    .createTempSync('dart_test_')
    .resolveSymbolicLinksSync();

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
    return list.reversed
        .where((byte) {
          if (byte == 0) return false;
          if (byte == _carriageReturn && previous == _newline) return false;
          previous = byte;
          return true;
        })
        .toList()
        .reversed
        .toList();
  });
}

/// Wraps [text] so that it fits within [lineLength].
///
/// This preserves existing newlines and doesn't consider terminal color escapes
/// part of a word's length. It only splits words on spaces, not on other sorts
/// of whitespace.
String wordWrap(String text) {
  return text.split("\n").map((originalLine) {
    var buffer = new StringBuffer();
    var lengthSoFar = 0;
    for (var word in originalLine.split(" ")) {
      var wordLength = withoutColors(word).length;
      if (wordLength > lineLength) {
        if (lengthSoFar != 0) buffer.writeln();
        buffer.writeln(word);
      } else if (lengthSoFar == 0) {
        buffer.write(word);
        lengthSoFar = wordLength;
      } else if (lengthSoFar + 1 + wordLength > lineLength) {
        buffer.writeln();
        buffer.write(word);
        lengthSoFar = wordLength;
      } else {
        buffer.write(" $word");
        lengthSoFar += 1 + wordLength;
      }
    }
    return buffer.toString();
  }).join("\n");
}

/// Print a warning containing [message].
///
/// This automatically wraps lines if they get too long. If [color] is passed,
/// it controls whether the warning header is color; otherwise, it defaults to
/// [canUseSpecialChars].
///
/// If [print] is `true`, this prints the message using [print] to associate it
/// with the current test. Otherwise, it prints it using [stderr].
void warn(String message, {bool color, bool print: false}) {
  if (color == null) color = canUseSpecialChars;
  var header = color ? "\u001b[33mWarning:\u001b[0m" : "Warning:";
  (print ? core.print : stderr.writeln)(wordWrap("$header $message\n"));
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
Future<T> getUnusedPort<T>(FutureOr<T> tryPort(int port)) async {
  T value;
  await Future.doWhile(() async {
    value = await tryPort(await getUnsafeUnusedPort());
    return value == null;
  });
  return value;
}

/// Whether this computer supports binding to IPv6 addresses.
var _maySupportIPv6 = true;

/// Returns a port that is probably, but not definitely, not in use.
///
/// This has a built-in race condition: another process may bind this port at
/// any time after this call has returned. If at all possible, callers should
/// use [getUnusedPort] instead.
Future<int> getUnsafeUnusedPort() async {
  var socket;
  if (_maySupportIPv6) {
    try {
      socket = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V6, 0,
          v6Only: true);
    } on SocketException {
      _maySupportIPv6 = false;
    }
  }
  if (!_maySupportIPv6) {
    socket = await RawServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  }
  var port = socket.port;
  await socket.close();
  return port;
}

/// Returns the full URL of the Chrome remote debugger for the main page.
///
/// This takes the [base] remote debugger URL (which points to a browser-wide
/// page) and uses its JSON API to find the resolved URL for debugging the host
/// page.
Future<Uri> getRemoteDebuggerUrl(Uri base) async {
  try {
    var client = new HttpClient();
    var request = await client.getUrl(base.resolve("/json/list"));
    var response = await request.close();
    var jsonObject =
        await json.fuse(utf8).decoder.bind(response).single as List;
    return base.resolve(jsonObject.first["devtoolsFrontendUrl"]);
  } catch (_) {
    // If we fail to talk to the remote debugger protocol, give up and return
    // the raw URL rather than crashing.
    return base;
  }
}
