// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:dwds/dwds.dart';
import 'package:dwds/asset_handler.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_proxy/shelf_proxy.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

import 'live_suite_controller.dart';
import 'runner_suite.dart';

class TestAssetHandler implements AssetHandler {
  final Uri _assetPrefix;

  Handler _handler;

  TestAssetHandler(this._assetPrefix);

  @override
  Handler get handler =>
      _handler ??= proxyHandler(this._assetPrefix.toString());

  @override
  Future<Response> getRelativeAsset(String path) async => handler(
      Request('GET', Uri.parse('${this._assetPrefix.toString()}/$path')));
}

/// Collects coverage and outputs to the [coverage] path.
Future<void> gatherCoverage(
    String coverage, LiveSuiteController controller) async {
  final RunnerSuite suite = controller.liveSuite.suite;

  if (suite.platform.runtime.isDartVM) {
    final String isolateId =
        Uri.parse(suite.environment.observatoryUrl.fragment)
            .queryParameters['isolateId'];

    final cov = await collect(
        suite.environment.observatoryUrl, false, false, false, Set(),
        isolateIds: {isolateId});

    final outfile = File(p.join('$coverage', '${suite.path}.vm.json'))
      ..createSync(recursive: true);
    final IOSink out = outfile.openWrite();
    out.write(json.encode(cov));
    await out.flush();
    await out.close();
  } else if (suite.platform.runtime.isBrowser &&
      suite.environment.supportsDebugging &&
      suite.environment.remoteDebuggerUrl != null) {
    print(' HERE! ${suite.environment.remoteDebuggerUrl.toString()}');
    final chromeConnection = ChromeConnection('localhost', suite.environment.remoteDebuggerUrl.port);
    print(' TABS! ${(await chromeConnection.getTabs()).length}');
    final dwds = await Dwds.start(
        assetHandler: TestAssetHandler(suite.config.baseUrl),
        buildResults: Stream.empty(),
        chromeConnection: () async {
          return chromeConnection;
        },
        enableDebugging: true,
        hostname: 'localhost');
    print(' we have a dwds instance ');
    final connectedApp = await dwds.connectedApps.first;
    print(' we have a connected app! ');
    final debugConnection = await dwds.debugConnection(connectedApp);
    print(' we have a debugConnection ');
    final response = await debugConnection.vmService.callServiceExtension('ext.dwds.enableProfiler');
    print(' GOT A RESPONSE HOLY SH*T ${response.toString()}');
  }
}
