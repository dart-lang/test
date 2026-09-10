// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/application_exception.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/errors.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/io.dart'; // ignore: implementation_imports

import '../executable_settings.dart';
import 'browser.dart';
import 'default_settings.dart';

/// A class for running an instance of Safari.
///
/// Any errors starting or running the process are reported through [onExit].
class Safari extends Browser {
  @override
  final name = 'Safari';

  Safari(Uri url, {ExecutableSettings? settings})
    : super(
        () => _startBrowser(url, settings ?? defaultSettings[Runtime.safari]!),
      );

  /// Starts a new instance of Safari open to the given [url].
  static Future<Process> _startBrowser(
    Uri url,
    ExecutableSettings settings,
  ) async {
    var port = await getUnusedPort<int>((p) async => p);
    Process process;
    try {
      process = await Process.start(settings.executable, [
        ...settings.arguments,
        '--port',
        port.toString(),
      ]);
    } catch (e) {
      throw ApplicationException(
        'Failed to start safaridriver: ${getErrorMessage(e)}.\n\n'
        '$_safariDriverInstructions',
      );
    }

    Future<void> connect() async {
      var sessionCreated = false;
      try {
        var httpClient = HttpClient();
        try {
          var response = await _sendRequest(
            httpClient,
            port,
            '/session',
            '{"capabilities": {"alwaysMatch": {"browserName": "Safari"}}}',
          );
          var json = jsonDecode(response) as Map<String, dynamic>;

          var value = json['value'] as Map<String, dynamic>?;
          if (value != null && value.containsKey('error')) {
            var message = value['message'] as String? ?? 'Unknown error';
            process.kill();
            throw ApplicationException(
              'safaridriver failed to create a session: $message\n\n'
              '$_safariDriverInstructions',
            );
          }

          var sessionId = value!['sessionId'] as String;
          sessionCreated = true;

          await _sendRequest(
            httpClient,
            port,
            '/session/$sessionId/url',
            '{"url": "${url.toString()}"}',
          );
        } finally {
          httpClient.close();
        }
      } catch (e) {
        if (!sessionCreated) {
          process.kill();
        }
        rethrow;
      }
    }

    unawaited(connect());

    return process;
  }
}

Future<String> _sendRequest(
  HttpClient client,
  int port,
  String path,
  String body,
) async {
  var retries = 0;
  while (true) {
    try {
      var request = await client.post('127.0.0.1', port, path);
      request.headers.contentType = ContentType.json;
      var encodedBody = utf8.encode(body);
      request.headers.contentLength = encodedBody.length;
      request.add(encodedBody);
      var response = await request.close();
      return await response.transform(utf8.decoder).join();
    } catch (e) {
      if (retries > 5) rethrow;
      retries++;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}

const _safariDriverInstructions = '''
Safari requires 'safaridriver' to be enabled to allow remote automation.
To enable it, run:

safaridriver --enable
(You may need to prefix with sudo: sudo safaridriver --enable)

Or in Safari: Settings -> Developer -> Allow Remote Automation.
''';
