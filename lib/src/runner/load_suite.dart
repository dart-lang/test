// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../test.dart';
import '../backend/group.dart';
import '../backend/invoker.dart';
import '../backend/metadata.dart';
import '../backend/suite.dart';
import '../backend/suite_platform.dart';
import '../backend/test.dart';
import '../backend/runtime.dart';
import '../util/io.dart';
import '../utils.dart';
import 'configuration/suite.dart';
import 'load_exception.dart';
import 'plugin/environment.dart';
import 'runner_suite.dart';

/// The timeout for loading a test suite.
///
/// We want this to be long enough that even a very large application being
/// compiled with dart2js doesn't trigger it, but short enough that it fires
/// before the host kills it. For example, Google's Forge service has a
/// 15-minute timeout.
final _timeout = new Duration(minutes: 12);

/// A [Suite] emitted by a [Loader] that provides a test-like interface for
/// loading a test file.
///
/// This is used to expose the current status of test loading to the user. It's
/// important to provide users visibility into what's taking a long time and
/// where failures occur. And since some tests may be loaded at the same time as
/// others are run, it's useful to provide that visibility in the form of a test
/// suite so that it can integrate well into the existing reporting interface
/// without too much extra logic.
///
/// A suite is constructed with logic necessary to produce a test suite. As with
/// a normal test body, this logic isn't run until [LiveTest.run] is called. The
/// suite itself is returned by [suite] once it's avaialble, but any errors or
/// prints will be emitted through the running [LiveTest].
class LoadSuite extends Suite implements RunnerSuite {
  final environment = const PluginEnvironment();
  final SuiteConfiguration config;
  final isDebugging = false;
  final onDebugging = new StreamController<bool>().stream;

  /// A future that completes to the loaded suite once the suite's test has been
  /// run and completed successfully.
  ///
  /// This will return `null` if the suite is unavailable for some reason (for
  /// example if an error occurred while loading it).
  Future<RunnerSuite> get suite async => (await _suiteAndZone)?.first;

  /// A future that completes to a pair of [suite] and the load test's [Zone].
  ///
  /// This will return `null` if the suite is unavailable for some reason (for
  /// example if an error occurred while loading it).
  final Future<Pair<RunnerSuite, Zone>> _suiteAndZone;

  /// Returns the test that loads the suite.
  ///
  /// Load suites are guaranteed to only contain one test. This is a utility
  /// method for accessing it directly.
  Test get test => this.group.entries.single as Test;

  /// Creates a load suite named [name] on [platform].
  ///
  /// [body] may return either a [RunnerSuite] or a [Future] that completes to a
  /// [RunnerSuite]. Its return value is forwarded through [suite], although if
  /// it throws an error that will be forwarded through the suite's test.
  ///
  /// If the the load test is closed before [body] is complete, it will close
  /// the suite returned by [body] once it completes.
  factory LoadSuite(String name, SuiteConfiguration config,
      SuitePlatform platform, FutureOr<RunnerSuite> body(),
      {String path}) {
    var completer = new Completer<Pair<RunnerSuite, Zone>>.sync();
    return new LoadSuite._(name, config, platform, () {
      var invoker = Invoker.current;
      invoker.addOutstandingCallback();

      invoke(() async {
        var suite = await body();
        if (completer.isCompleted) {
          // If the load test has already been closed, close the suite it
          // generated.
          suite?.close();
          return;
        }

        completer
            .complete(suite == null ? null : new Pair(suite, Zone.current));
        invoker.removeOutstandingCallback();
      });

      // If the test completes before the body callback, either an out-of-band
      // error occurred or the test was canceled. Either way, we return a `null`
      // suite.
      invoker.liveTest.onComplete.then((_) {
        if (!completer.isCompleted) completer.complete();
      });

      // If the test is forcibly closed, let it complete, since load tests don't
      // have timeouts.
      invoker.onClose.then((_) => invoker.removeOutstandingCallback());
    }, completer.future, path: path);
  }

  /// A utility constructor for a load suite that just throws [exception].
  ///
  /// The suite's name will be based on [exception]'s path.
  factory LoadSuite.forLoadException(
      LoadException exception, SuiteConfiguration config,
      {SuitePlatform platform, StackTrace stackTrace}) {
    if (stackTrace == null) stackTrace = new Trace.current();

    return new LoadSuite(
        "loading ${exception.path}",
        config ?? SuiteConfiguration.empty,
        platform ?? currentPlatform(Runtime.vm),
        () => new Future.error(exception, stackTrace),
        path: exception.path);
  }

  /// A utility constructor for a load suite that just emits [suite].
  factory LoadSuite.forSuite(RunnerSuite suite) {
    return new LoadSuite(
        "loading ${suite.path}", suite.config, suite.platform, () => suite,
        path: suite.path);
  }

  LoadSuite._(String name, this.config, SuitePlatform platform, void body(),
      this._suiteAndZone, {String path})
      : super(
            new Group.root([
              new LocalTest(
                  name, new Metadata(timeout: new Timeout(_timeout)), body)
            ]),
            platform,
            path: path);

  /// A constructor used by [changeSuite].
  LoadSuite._changeSuite(LoadSuite old, this._suiteAndZone)
      : config = old.config,
        super(old.group, old.platform, path: old.path);

  /// A constructor used by [filter].
  LoadSuite._filtered(LoadSuite old, Group filtered)
      : config = old.config,
        _suiteAndZone = old._suiteAndZone,
        super(old.group, old.platform, path: old.path);

  /// Creates a new [LoadSuite] that's identical to this one, but that
  /// transforms [suite] once it's loaded.
  ///
  /// If [suite] completes to `null`, [change] won't be run. [change] is run
  /// within the load test's zone, so any errors or prints it emits will be
  /// associated with that test.
  LoadSuite changeSuite(RunnerSuite change(RunnerSuite suite)) {
    return new LoadSuite._changeSuite(this, _suiteAndZone.then((pair) {
      if (pair == null) return null;

      var zone = pair.last;
      var newSuite;
      zone.runGuarded(() {
        newSuite = change(pair.first);
      });
      return newSuite == null ? null : new Pair(newSuite, zone);
    }));
  }

  /// Runs the test and returns the suite.
  ///
  /// Rather than emitting errors through a [LiveTest], this just pipes them
  /// through the return value.
  Future<RunnerSuite> getSuite() async {
    var liveTest = test.load(this);
    liveTest.onMessage.listen((message) => print(message.text));
    await liveTest.run();

    if (liveTest.errors.isEmpty) return await suite;

    var error = liveTest.errors.first;
    await new Future.error(error.error, error.stackTrace);
    throw 'unreachable';
  }

  LoadSuite filter(bool callback(Test test)) {
    var filtered = this.group.filter(callback);
    if (filtered == null) filtered = new Group.root([], metadata: metadata);
    return new LoadSuite._filtered(this, filtered);
  }

  StreamChannel channel(String name) =>
      throw new UnsupportedError("LoadSuite.channel() is not supported.");

  Future close() async {}
}
