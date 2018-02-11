// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:multi_server_socket/multi_server_socket.dart';
import 'package:node_preamble/preamble.dart' as preamble;
import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';
import 'package:yaml/yaml.dart';

import '../../backend/compiler.dart';
import '../../backend/test_platform.dart';
import '../../util/io.dart';
import '../../util/stack_trace_mapper.dart';
import '../../utils.dart';
import '../application_exception.dart';
import '../build.dart' as build;
import '../compiler_pool.dart';
import '../configuration.dart';
import '../configuration/suite.dart';
import '../executable_settings.dart';
import '../load_exception.dart';
import '../plugin/customizable_platform.dart';
import '../plugin/environment.dart';
import '../plugin/platform.dart';
import '../plugin/platform_helpers.dart';
import '../runner_suite.dart';

/// A platform that loads tests in Node.js processes.
class NodePlatform extends PlatformPlugin
    implements CustomizablePlatform<ExecutableSettings> {
  /// The test runner configuration.
  final Configuration _config;

  /// The [CompilerPool] managing active instances of `dart2js`.
  final _compilers = new CompilerPool(["-Dnode=true"]);

  /// The temporary directory in which compiled JS is emitted.
  final _compiledDir = createTempDir();

  /// The HTTP client to use when fetching JS files for `pub serve`.
  final HttpClient _http;

  /// Executable settings for [TestPlatform.nodeJS] and platforms that extend
  /// it.
  final _settings = {
    TestPlatform.nodeJS: new ExecutableSettings(
        linuxExecutable: "node",
        macOSExecutable: "node",
        windowsExecutable: "node.exe")
  };

  NodePlatform()
      : _config = Configuration.current,
        _http =
            Configuration.current.pubServeUrl == null ? null : new HttpClient();

  ExecutableSettings parsePlatformSettings(YamlMap settings) =>
      new ExecutableSettings.parse(settings);

  ExecutableSettings mergePlatformSettings(
          ExecutableSettings settings1, ExecutableSettings settings2) =>
      settings1.merge(settings2);

  void customizePlatform(TestPlatform platform, ExecutableSettings settings) {
    var oldSettings = _settings[platform] ?? _settings[platform.root];
    if (oldSettings != null) settings = oldSettings.merge(settings);
    _settings[platform] = settings;
  }

  StreamChannel loadChannel(String path, TestPlatform platform) =>
      throw new UnimplementedError();

  Future<RunnerSuite> load(String path, TestPlatform platform,
      SuiteConfiguration suiteConfig, Object message) async {
    assert(platform == TestPlatform.nodeJS);

    var compiler = Compiler.find((message as Map)['compiler'] as String);

    var pair = await _loadChannel(path, platform, compiler, suiteConfig);
    var controller = await deserializeSuite(path, platform, suiteConfig,
        new PluginEnvironment(), pair.first, message,
        mapper: pair.last);
    return controller.suite;
  }

  /// Loads a [StreamChannel] communicating with the test suite at [path].
  ///
  /// Returns that channel along with a [StackTraceMapper] representing the
  /// source map for the compiled suite.
  Future<Pair<StreamChannel, StackTraceMapper>> _loadChannel(
      String path,
      TestPlatform platform,
      Compiler compiler,
      SuiteConfiguration suiteConfig) async {
    var server = await MultiServerSocket.loopback(0);

    var pair =
        await _spawnProcess(path, platform, compiler, suiteConfig, server.port);
    var process = pair.first;

    // Forward Node's standard IO to the print handler so it's associated with
    // the load test.
    //
    // TODO(nweiz): Associate this with the current test being run, if any.
    process.stdout.transform(lineSplitter).listen(print);
    process.stderr.transform(lineSplitter).listen(print);

    var socket = await server.first;
    // TODO(nweiz): Remove the DelegatingStreamSink wrapper when sdk#31504 is
    // fixed.
    var channel = new StreamChannel(socket, new DelegatingStreamSink(socket))
        .transform(new StreamChannelTransformer.fromCodec(UTF8))
        .transform(chunksToLines)
        .transform(jsonDocument)
        .transformStream(new StreamTransformer.fromHandlers(handleDone: (sink) {
      if (process != null) process.kill();
      sink.close();
    }));

    return new Pair(channel, pair.last);
  }

  /// Spawns a Node.js process that loads the Dart test suite at [path].
  ///
  /// Returns that channel along with a [StackTraceMapper] representing the
  /// source map for the compiled suite.
  Future<Pair<Process, StackTraceMapper>> _spawnProcess(
      String path,
      TestPlatform platform,
      Compiler compiler,
      SuiteConfiguration suiteConfig,
      int socketPort) async {
    var dir = new Directory(_compiledDir).createTempSync('test_').path;
    var jsPath = p.join(dir, p.basename(path) + ".node_test.dart.js");

    StackTraceMapper mapper;
    if (_config.pubServeUrl != null) {
      mapper = await _downloadPubServeSuite(path, jsPath, suiteConfig);
    } else if (compiler == Compiler.build) {
      await _writeBuildSuite(path, jsPath);
    } else {
      mapper = await _compileSuite(path, jsPath, suiteConfig);
    }

    return new Pair(await _startProcess(platform, jsPath, socketPort), mapper);
  }

  /// Compiles the test suite at [dartPath] to JavaScript at [jsPath] from `pub
  /// serve`.
  ///
  /// If [suiteConfig.jsTrace] is `true`, returns a [StackTraceMapper] that will
  /// convert JS stack traces to Dart.
  Future<StackTraceMapper> _downloadPubServeSuite(
      String dartPath, String jsPath, SuiteConfiguration suiteConfig) async {
    var url = _config.pubServeUrl.resolveUri(
        p.toUri(p.relative(dartPath, from: 'test') + '.node_test.dart.js'));

    var js = await _get(url, dartPath);
    await new File(jsPath)
        .writeAsString(preamble.getPreamble(minified: true) + js);
    if (suiteConfig.jsTrace) return null;

    var mapUrl = url.replace(path: url.path + '.map');
    return new StackTraceMapper(await _get(mapUrl, dartPath),
        mapUrl: mapUrl,
        packageResolver: new SyncPackageResolver.root('packages'),
        sdkRoot: p.toUri('packages/\$sdk'));
  }

  Future _writeBuildSuite(String dartPath, String jsPath) async {
    var bootstrapPath = await _compileBootstrap();

    var modulePaths = {
      "dart_sdk": p.join(sdkDir, 'lib/dev_compiler/amd/dart_sdk'),
      "packages/test/src/bootstrap/node": p.withoutExtension(bootstrapPath)
    };
    for (var path in build.ddcModules) {
      var components = p.split(p.relative(path, from: build.generatedDir));
      Uri module;
      if (components[1] == 'lib') {
        var package = components.first;
        var pathInLib = p.joinAll(components.skip(2));
        module = p.toUri(p.join('packages', package, pathInLib));
      } else {
        assert(components.first == rootPackageName);
        module = p.toUri(p.joinAll(components.skip(1)));
      }
      modulePaths[module.toString()] = p.absolute("$path.ddc");
    }

    var moduleName = p.withoutExtension(dartPath);

    var requires = [moduleName, "packages/test/src/bootstrap/node", "dart_sdk"];
    var moduleIdentifier =
        p.url.split(moduleName).skip(1).join('__').replaceAll('.', '\$46');

    var requirejsPath = p.fromUri(await Isolate.resolvePackageUri(
        Uri.parse('package:test/src/runner/node/vendor/r.js')));

    new File(jsPath).writeAsStringSync('''
      ${preamble.getPreamble()}

      (function() {
        let requirejs = require(${JSON.encode(requirejsPath)});
        requirejs.config({waitSeconds: 0, paths: ${JSON.encode(modulePaths)}});

        requirejs(${JSON.encode(requires)}, function(app, bootstrap, dart_sdk) {
          dart_sdk._isolate_helper.startRootIsolate(() => {}, []);
          dart_sdk._debugger.registerDevtoolsFormatter();
          dart_sdk.dart.global = self;
          global.self = self;
          self.\$dartTestGetSourceMap = dart_sdk.dart.getSourceMap;

          bootstrap.src__bootstrap__node.internalBootstrapNodeTest(
              function() {
            return app.$moduleIdentifier.main;
          });
        });
      })();
    ''');
  }

  /// Compiles the test suite at [dartPath] to JavaScript at [jsPath] using
  /// dart2js.
  ///
  /// If [suiteConfig.jsTrace] is `true`, returns a [StackTraceMapper] that will
  /// convert JS stack traces to Dart.
  Future<StackTraceMapper> _compileSuite(
      String dartPath, String jsPath, SuiteConfiguration suiteConfig) async {
    await _compilers.compile('''
      import "package:test/src/bootstrap/node.dart";

      import "${p.toUri(p.absolute(dartPath))}" as test;

      void main() {
        internalBootstrapNodeTest(() => test.main);
      }
    ''', jsPath, suiteConfig);

    // Add the Node.js preamble to ensure that the dart2js output is
    // compatible. Use the minified version so the source map remains valid.
    var jsFile = new File(jsPath);
    await jsFile.writeAsString(
        preamble.getPreamble(minified: true) + await jsFile.readAsString());
    if (suiteConfig.jsTrace) return null;

    var mapPath = jsPath + '.map';
    return new StackTraceMapper(await new File(mapPath).readAsString(),
        mapUrl: p.toUri(mapPath),
        packageResolver: await PackageResolver.current.asSync,
        sdkRoot: p.toUri(sdkDir));
  }

  /// Starts the Node.js process for [platform] with [jsPath].
  Future<Process> _startProcess(
      TestPlatform platform, String jsPath, int socketPort) async {
    var settings = _settings[platform];

    var nodeModules = p.absolute('node_modules');
    var nodePath = Platform.environment["NODE_PATH"];
    nodePath = nodePath == null ? nodeModules : "$nodePath:$nodeModules";

    try {
      return await Process.start(settings.executable,
          settings.arguments.toList()..add(jsPath)..add(socketPort.toString()),
          environment: {'NODE_PATH': nodePath});
    } catch (error, stackTrace) {
      await new Future.error(
          new ApplicationException(
              "Failed to run ${platform.name}: ${getErrorMessage(error)}"),
          stackTrace);
      return null;
    }
  }

  /// Compiles "package:test/src/bootstrap/node.dart" to JS using DDC and
  /// returns the path to the compiled result.
  Future<String> _compileBootstrap() async {
    // Pass the error through a result to avoid cross-zone issues.
    var result = await _compileBootstrapMemo.runOnce(() {
      return Result.capture(new Future(() async {
        var js = await build.compile("package:test/src/bootstrap/node.dart");
        var jsPath = p.join(_compiledDir, 'bootstrap.dart.js');
        new File(jsPath).writeAsStringSync(js);
        return jsPath;
      }));
    });
    return await result.asFuture;
  }

  final _compileBootstrapMemo = new AsyncMemoizer<Result<String>>();

  /// Runs an HTTP GET on [url].
  ///
  /// If this fails, throws a [LoadException] for [suitePath].
  Future<String> _get(Uri url, String suitePath) async {
    try {
      var response = await (await _http.getUrl(url)).close();

      if (response.statusCode != 200) {
        // We don't care about the response body, but we have to drain it or
        // else the process can't exit.
        response.listen(null);

        throw new LoadException(
            suitePath,
            "Error getting $url: ${response.statusCode} "
            "${response.reasonPhrase}\n"
            'Make sure "pub serve" is serving the test/ directory.');
      }

      return await UTF8.decodeStream(response);
    } on IOException catch (error) {
      var message = getErrorMessage(error);
      if (error is SocketException) {
        message = "${error.osError.message} "
            "(errno ${error.osError.errorCode})";
      }

      throw new LoadException(
          suitePath,
          "Error getting $url: $message\n"
          'Make sure "pub serve" is running.');
    }
  }

  Future close() => _closeMemo.runOnce(() async {
        await _compilers.close();

        if (_config.pubServeUrl == null) {
          new Directory(_compiledDir).deleteSync(recursive: true);
        } else {
          _http.close();
        }
      });
  final _closeMemo = new AsyncMemoizer();
}
