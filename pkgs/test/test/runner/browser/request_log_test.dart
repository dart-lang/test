// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:shelf/shelf.dart' as shelf;
import 'package:test/src/runner/browser/request_log.dart';
import 'package:test/test.dart';

final _webSocketUrl = Uri.parse('ws://localhost:1234/secret/0');
final _hostPage = Uri.parse(
  'http://localhost:1234/secret/packages/test/src/runner/browser/static/'
  'index.html',
).replace(queryParameters: {'managerUrl': '$_webSocketUrl'});

void main() {
  late BrowserRequestLog log;
  late shelf.Handler handler;
  late DateTime start;

  setUp(() {
    log = BrowserRequestLog();
    handler = log.wrap((request) => shelf.Response.ok(''));
    start = DateTime.now();
  });

  test('records the host page and resources it loads', () async {
    await handler(shelf.Request('GET', _hostPage));
    await handler(
      shelf.Request(
        'GET',
        Uri.parse('http://localhost:1234/secret/host.dart.js'),
        headers: {'referer': '$_hostPage'},
      ),
    );

    expect(log.describe(_webSocketUrl, start), [
      startsWith('index.html (200) after '),
      startsWith('host.dart.js (200) after '),
    ]);
  });

  test('records WebSocket upgrades', () async {
    handler = log.wrap((request) => throw const shelf.HijackException());
    await expectLater(
      handler(
        shelf.Request(
          'GET',
          Uri.parse('http://localhost:1234/secret/0'),
          headers: {'upgrade': 'websocket'},
        ),
      ),
      throwsA(isA<shelf.HijackException>()),
    );

    expect(log.describe(_webSocketUrl, start), [
      startsWith('WebSocket upgrade (upgraded) after '),
    ]);
  });

  test('ignores requests for other browser managers', () async {
    await handler(
      shelf.Request(
        'GET',
        _hostPage.replace(
          queryParameters: {'managerUrl': 'ws://localhost:1234/secret/1'},
        ),
      ),
    );
    await handler(
      shelf.Request('GET', Uri.parse('http://localhost:1234/secret/other.js')),
    );

    expect(log.describe(_webSocketUrl, start), isEmpty);
  });

  test('ignores requests before the given time', () async {
    await handler(shelf.Request('GET', _hostPage));

    expect(
      log.describe(_webSocketUrl, DateTime.now().add(const Duration(days: 1))),
      isEmpty,
    );
  });

  test('does not include the server secret', () async {
    await handler(shelf.Request('GET', _hostPage));

    expect(
      log.describe(_webSocketUrl, start).single,
      isNot(contains('secret')),
    );
  });
}
