// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.load_suite;

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

import '../../test.dart';
import '../backend/invoker.dart';
import '../backend/metadata.dart';
import '../backend/suite.dart';
import '../backend/test_platform.dart';
import '../utils.dart';
import 'load_exception.dart';

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
class LoadSuite extends Suite {
  /// A future that completes to the loaded suite once the suite's test has been
  /// run and completed successfully.
  ///
  /// This will return `null` if the suite is unavailable for some reason (for
  /// example if an error occurred while loading it).
  final Future<Suite> suite;

  /// Creates a load suite named [name] on [platform].
  ///
  /// [body] may return either a [Suite] or a [Future] that completes to a
  /// [Suite]. Its return value is forwarded through [suite], although if it
  /// throws an error that will be forwarded through the suite's test.
  ///
  /// If the the load test is closed before [body] is complete, it will close
  /// the suite returned by [body] once it completes.
  factory LoadSuite(String name, body(), {TestPlatform platform}) {
    var completer = new Completer.sync();
    return new LoadSuite._(name, () {
      var invoker = Invoker.current;
      invoker.addOutstandingCallback();

      invoke(() async {
        try {
          var suite = await body();
          if (completer.isCompleted) {
            // If the load test has already been closed, close the suite it
            // generated.
            suite.close();
            return;
          }

          completer.complete(suite);
          invoker.removeOutstandingCallback();
        } catch (error, stackTrace) {
          registerException(error, stackTrace);
          if (!completer.isCompleted) completer.complete();
        }
      });

      // If the test is forcibly closed, exit immediately. It doesn't have any
      // cleanup to do that won't be handled by Loader.close.
      invoker.onClose.then((_) {
        if (completer.isCompleted) return;
        completer.complete();
        invoker.removeOutstandingCallback();
      });
    }, completer.future, platform: platform);
  }

  /// A utility constructor for a load suite that just throws [exception].
  ///
  /// The suite's name will be based on [exception]'s path.
  factory LoadSuite.forLoadException(LoadException exception,
      {StackTrace stackTrace, TestPlatform platform}) {
    if (stackTrace == null) stackTrace = new Trace.current();

    return new LoadSuite("loading ${exception.path}", () {
      return new Future.error(exception, stackTrace);
    }, platform: platform);
  }

  /// A utility constructor for a load suite that just emits [suite].
  factory LoadSuite.forSuite(Suite suite) {
    return new LoadSuite("loading ${suite.path}", () => suite,
        platform: suite.platform);
  }

  LoadSuite._(String name, void body(), this.suite, {TestPlatform platform})
      : super([
        new LocalTest(name,
            new Metadata(timeout: new Timeout(new Duration(minutes: 5))),
            body)
      ], platform: platform);

  /// A constructor used by [changeSuite].
  LoadSuite._changeSuite(LoadSuite old, Future<Suite> this.suite)
      : super(old.tests, platform: old.platform);

  /// Creates a new [LoadSuite] that's identical to this one, but that
  /// transforms [suite] once it's loaded.
  ///
  /// If [suite] completes to `null`, [change] won't be run.
  LoadSuite changeSuite(Suite change(Suite suite)) {
    return new LoadSuite._changeSuite(this, suite.then((loadedSuite) {
      if (loadedSuite == null) return null;
      return change(loadedSuite);
    }));
  }

  /// Runs the test and returns the suite.
  ///
  /// Rather than emitting errors through a [LiveTest], this just pipes them
  /// through the return value.
  Future<Suite> getSuite() async {
    var liveTest = await tests.single.load(this);
    liveTest.onPrint.listen(print);
    await liveTest.run();

    if (liveTest.errors.isEmpty) return await suite;

    var error = liveTest.errors.first;
    await new Future.error(error.error, error.stackTrace);
    throw 'unreachable';
  }
}
