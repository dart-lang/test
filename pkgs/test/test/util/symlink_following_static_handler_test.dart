// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/src/util/symlink_following_static_handler.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  late HttpServer server;

  setUp(() async {
    await d.dir('outside', [d.file('secret.txt', 'secret')]).create();
    await d.dir('root', [
      d.file('inside.txt', 'inside'),
      d.dir('sub', [d.file('nested.txt', 'nested')]),
    ]).create();
    server = await shelf_io.serve(
      createSymlinkFollowingStaticHandler(p.join(d.sandbox, 'root')),
      InternetAddress.loopbackIPv4,
      0,
    );
  });

  tearDown(() => server.close(force: true));

  /// Sends a request for [path] exactly as written, without any client side
  /// normalization.
  Future<({int status, String body})> rawGet(String path) async {
    var socket = await Socket.connect(server.address, server.port);
    socket.write(
      'GET $path HTTP/1.1\r\n'
      'Host: localhost\r\n'
      'Connection: close\r\n'
      '\r\n',
    );
    var response = await utf8.decoder.bind(socket).join();
    socket.destroy();
    var statusLine = response.substring(0, response.indexOf('\r\n'));
    var body = response.substring(response.indexOf('\r\n\r\n') + 4);
    return (status: int.parse(statusLine.split(' ')[1]), body: body);
  }

  test('serves files within the root', () async {
    expect(await rawGet('/inside.txt'), (status: 200, body: 'inside'));
    expect(await rawGet('/sub/nested.txt'), (status: 200, body: 'nested'));
  });

  test('returns a 404 for missing files', () async {
    expect((await rawGet('/missing.txt')).status, 404);
  });

  test('serves symlinks within the root that point outside of it', () async {
    Link(
      p.join(d.sandbox, 'root', 'link.txt'),
    ).createSync(p.join(d.sandbox, 'outside', 'secret.txt'));
    Link(
      p.join(d.sandbox, 'root', 'linked_dir'),
    ).createSync(p.join(d.sandbox, 'outside'));

    expect(await rawGet('/link.txt'), (status: 200, body: 'secret'));
    expect(await rawGet('/linked_dir/secret.txt'), (
      status: 200,
      body: 'secret',
    ));
  }, testOn: '!windows');

  group('does not serve files outside the root', () {
    for (var path in [
      '/../outside/secret.txt',
      '/%2E%2E/outside/secret.txt',
      '/..%2Foutside%2Fsecret.txt',
      '/sub/..%2F..%2Foutside%2Fsecret.txt',
      '/sub/%2E%2E%2F%2E%2E%2Foutside%2Fsecret.txt',
    ]) {
      test(path, () async {
        var response = await rawGet(path);
        expect(response.status, isNot(200));
        expect(response.body, isNot(contains('secret')));
      });
    }

    test('with an absolute path segment', () async {
      var secretPath = p.join(d.sandbox, 'outside', 'secret.txt');
      var response = await rawGet('/${Uri.encodeComponent(secretPath)}');
      expect(response.status, isNot(200));
      expect(response.body, isNot(contains('secret')));
    });
  });
}
