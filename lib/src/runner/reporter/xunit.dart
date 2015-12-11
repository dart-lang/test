// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.reporter.xunit;

import 'dart:async';

import '../../backend/live_test.dart';
import '../../backend/state.dart';
import '../../backend/group.dart';
import '../../frontend/expect.dart';
import '../../utils.dart';
import '../engine.dart';
import '../load_suite.dart';
import '../reporter.dart';

class XunitFailure {
  String name;
  String stack;

  XunitFailure(this.name, this.stack);
}

class XunitFailureResult {
  bool failure;
  List<XunitFailure> failures = [];

  XunitFailureResult();

  add(XunitFailure failure) {
    failures.add(failure);
  }
}

class XunitTestResult {
  int beginningTime;
  int endTime;
  XunitFailureResult error;
  String name;
  String path;
  bool skipped = false;
  String skipReason;

  XunitTestResult(this.name, this.path, this.beginningTime);
}

class XunitTestSuite {
  int errored = 0;
  int failed = 0;
  int skipped = 0;
  List<XunitTestResult> testResults = [];
  Map<String, XunitTestSuite> testSuites = {};
  int tests = 0;

  XunitTestSuite() {
    this.errored = 0;
    this.failed = 0;
    this.skipped = 0;
    this.tests = 0;
  }

  add(XunitTestResult test) {
    testResults.add(test);
  }
}

/// A reporter that returns xunit compatible output.

class XunitReporter implements Reporter {
  /// The engine used to run the tests.
  final Engine _engine;

  /// A stopwatch that tracks the duration of the full run.
  final _stopwatch = new Stopwatch();

  /// Whether we've started [_stopwatch].
  ///
  /// We can't just use `_stopwatch.isRunning` because the stopwatch is stopped
  /// when the reporter is paused.
  var _stopwatchStarted = false;

  /// Whether the reporter is paused.
  var _paused = false;

  /// The set of all subscriptions to various streams.
  final _subscriptions = new Set<StreamSubscription>();

  /// Record of all tests run.
  Map _testCases = {};

  /// Number of failures that occur during the test run.
  int _failureCount = 0;

  /// Number of errors that occur during the test run.
  int _errorCount = 0;

  /// Map containing Xunit hierarchy.
  XunitTestSuite _groupStructure = new XunitTestSuite();

  /// Watches the tests run by [engine] and records its results.
  static XunitReporter watch(Engine engine) {
    return new XunitReporter._(engine);
  }

  XunitReporter._(this._engine) {
    _groupStructure.testSuites['rootNode'] = new XunitTestSuite();

    _subscriptions.add(_engine.onTestStarted.listen(_onTestStarted));

    /// Convert the future to a stream so that the subscription can be paused or
    /// canceled.
    _subscriptions.add(_engine.success.asStream().listen(_onDone));
  }

  void pause() {
    if (_paused) return;
    _paused = true;

    _stopwatch.stop();

    for (var subscription in _subscriptions) {
      subscription.pause();
    }
  }

  void resume() {
    if (!_paused) return;
    _paused = false;

    if (_stopwatchStarted) _stopwatch.start();

    for (var subscription in _subscriptions) {
      subscription.resume();
    }
  }

  void cancel() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// A callback called when the engine begins running [liveTest].
  void _onTestStarted(LiveTest liveTest) {
    if (liveTest.suite is! LoadSuite) {
      if (!_stopwatch.isRunning) _stopwatch.start();

      _subscriptions.add(liveTest.onStateChange
          .listen((state) => _onStateChange(liveTest, state)));
    }

    _subscriptions.add(liveTest.onError
        .listen((error) => _onError(liveTest, error.error, error.stackTrace)));

    _subscriptions.add(liveTest.onPrint.listen((line) {}));
  }

  List<String> _orderedGroupList(List<Group> listOfGroups) {
    List<String> separatedList = [];
    if (listOfGroups.length > 1) {
      separatedList.add(listOfGroups[1].name);
      for (int i = 2; i < listOfGroups.length; i++) {
        separatedList.add(listOfGroups[i]
            .name
            .replaceAll(listOfGroups[i - 1].name, '')
            .trim());
      }
    }
    return separatedList;
  }

  String _sanitizeXml(String original) {
    String updated = original.replaceAll('&', '&amp;');
    updated = updated.replaceAll('<', '&lt;');
    updated = updated.replaceAll('>', '&gt;');
    updated = updated.replaceAll('"', '&quot;');
    return updated = updated.replaceAll("'", '&apos;');
  }

  /// A callback called when [liveTest]'s state becomes [state].
  void _onStateChange(LiveTest liveTest, State state) {
    if (state.status != Status.complete) {
      if (state.status == Status.running) {
        String testName = _sanitizeXml(liveTest.individualName);

        _testCases[liveTest] = new XunitTestResult(
            testName, liveTest.suite.path, _stopwatch.elapsedMilliseconds);
        List listOfGroups = _orderedGroupList(liveTest.groups);
        XunitTestSuite listGroup = _groupStructure.testSuites['rootNode'];

        listOfGroups.forEach((String elem) {
          if (!listGroup.testSuites.containsKey(elem)) {
            listGroup.testSuites[elem] = new XunitTestSuite();
          }
          listGroup = listGroup.testSuites[elem];
        });

        listGroup.testResults.add(_testCases[liveTest]);
      }
      return;
    }

    _testCases[liveTest].endTime = _stopwatch.elapsedMilliseconds;

    if (liveTest.test.metadata.skip) {
      _testCases[liveTest].skipped = true;
      if (liveTest.test.metadata.skipReason != null) {
        _testCases[liveTest].skipReason = liveTest.test.metadata.skipReason;
      }
    }
  }

  /// A callback called when [liveTest] throws [error].
  void _onError(LiveTest liveTest, error, StackTrace stackTrace) {
    if (liveTest.state.status != Status.complete) return;
    if (_testCases[liveTest].error == null) {
      _testCases[liveTest].error = new XunitFailureResult();
      if (error is TestFailure) {
        _failureCount++;
        _testCases[liveTest].error.failure = true;
      } else {
        _errorCount++;
        _testCases[liveTest].error.failure = false;
      }
    }
    String body = _sanitizeXml(terseChain(stackTrace).toString().trim());
    _testCases[liveTest]
        .error
        .add(new XunitFailure(error.toString().replaceAll('\n', ''), body));
  }

  /// A method used to format individual testcases
  String _formatTestResults(List<XunitTestResult> list, {int depth}) {
    String results = '';
    list.forEach((XunitTestResult test) {
      String individualTest = '';
      String testName = _sanitizeXml(test.name);
      if (test.error == null && !test.skipped) {
        individualTest +=
            _indentLine('<testcase classname=\"${test.path}\" name=\"${testName}\" time=\"${test.endTime - test.beginningTime}\"> </testcase>', depth);
      } else {
        if (test.error != null) {
          individualTest +=
              _indentLine('<testcase classname=\"${test.path}\" name=\"${testName}\">', depth);
          if (test.error.failure) {
            test.error.failures.forEach((XunitFailure testFailure) {
              individualTest += _indentLine('<failure message="${_sanitizeXml(testFailure.name)}">', depth + 1);
              testFailure.stack.split('\n').forEach((line) {
                individualTest += _indentLine(line, depth + 2);
              });
              individualTest += _indentLine('</failure>', depth + 1);
            });
          } else {
            test.error.failures.forEach((XunitFailure testError) {
              individualTest += _indentLine('<error message="${_sanitizeXml(testError.name)}">', depth + 1);
              testError.stack.split('\n').forEach((line) {
                individualTest += _indentLine(line, depth + 2);
              });
              individualTest += _indentLine('</error>', depth + 1);
            });
          }
          individualTest += _indentLine('</testcase>', depth);
        } else {
          individualTest +=
              _indentLine('<testcase classname=\"${test.path}\" name=\"${testName}\">', depth);
          if (test.skipReason != null) {
            individualTest += _indentLine('<skipped message="${_sanitizeXml(test.skipReason)}"/>', depth + 1);
          } else {
            individualTest += _indentLine('<skipped/>', depth + 1);
          }
          individualTest += _indentLine('</testcase>', depth);
        }
      }
      results += individualTest;
    });
    return results;
  }

  /// Calculate the test totals for a suite and its children
  XunitTestSuite _suiteResults(
      Map<String, XunitTestSuite> group, XunitTestSuite suite) {
    XunitTestSuite currentSuite = suite;

    group.forEach((key, value) {
      value.testResults.forEach((XunitTestResult element) {
        currentSuite.tests++;
        if (element.skipped) {
          currentSuite.skipped++;
        }
        if (element.error != null) {
          if (element.error.failure) {
            currentSuite.failed++;
          } else {
            currentSuite.errored++;
          }
        }
      });
      if (group[key].testSuites.isNotEmpty) {
        _suiteResults(group[key].testSuites, currentSuite);
      }
    });

    return suite;
  }

  /// Format testsuite headings
  String _formatTestSuiteHeading(XunitTestSuite group) {
    XunitTestSuite suite = _suiteResults(group.testSuites, group);

    suite.testResults.forEach((XunitTestResult element) {
      suite.tests++;
      if (element.skipped) {
        suite.skipped++;
      }
      if (element.error != null) {
        if (element.error.failure) {
          suite.failed++;
        } else {
          suite.errored++;
        }
      }
    });

    String suiteHeading = '';
    if (suite.tests > 0) {
      suiteHeading += 'tests="${suite.tests}" ';
    }
    if (suite.failed > 0) {
      suiteHeading += 'failures="${suite.failed}" ';
    }
    if (suite.errored > 0) {
      suiteHeading += 'errors="${suite.errored}" ';
    }
    if (suite.skipped > 0) {
      suiteHeading += 'skipped="${suite.skipped}" ';
    }
    return suiteHeading.trimRight();
  }

  /// A method used to create a nested xml hierarchy
  String _formatXmlHierarchy(XunitTestSuite xmlMap, {int depth: 1}) {
    String result = '';
    xmlMap.testSuites.keys.forEach((String elem) {
      if (xmlMap.testSuites[elem] is XunitTestSuite) {
        var heading = _formatTestSuiteHeading(xmlMap.testSuites[elem]);
        result += _indentLine('<testsuite name="$elem" $heading>', depth);
        result += _formatTestResults(xmlMap.testSuites[elem].testResults, depth: depth + 1);
        result += _formatXmlHierarchy(xmlMap.testSuites[elem], depth: depth + 1);
        result += _indentLine('</testsuite>', depth);
      }
    });
    return result;
  }

  /// Indents a line by [depth] number of soft-tabs (2 space tabs). Also adds
  /// a newline at the end of the line.
  String _indentLine(String s, int depth) {
    if (depth <= 0) return s;
    return '  ' * depth + s + '\n';
  }

  /// A callback called when the engine is finished running tests.
  ///
  /// [success] will be `true` if all tests passed, `false` if some tests
  /// failed, and `null` if the engine was closed prematurely.
  void _onDone(bool success) {
    // A null success value indicates that the engine was closed before the
    // tests finished running, probably because of a signal from the user, in
    // which case we shouldn't print summary information.
    if (success == null) return;

    print('<?xml version="1.0" encoding="UTF-8" ?>');
    print(
        '<testsuite name="All tests" tests="${_engine.passed.length + _engine.skipped.length +_engine.failed.length}" '
        'errors="$_errorCount" failures="$_failureCount" skipped="${_engine.skipped.length}">');

    if (_groupStructure.testSuites['rootNode'].testSuites.isNotEmpty) {
      print(_formatXmlHierarchy(_groupStructure.testSuites['rootNode'])
          .trimRight());
    }
    if (_groupStructure.testSuites['rootNode'].testResults?.isNotEmpty) {
      print(_formatTestResults(
          _groupStructure.testSuites['rootNode'].testResults, depth: 1).trimRight());
    }

    print('</testsuite>');

    if (_engine.liveTests.isEmpty) {
      print('No tests ran.');
    }
  }
}
