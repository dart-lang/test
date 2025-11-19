// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

Future<void> main() async {
  group('environment', () {
    test('default', () async {
      await _run([], contains: _generateExpectedOutput());
    });

    group('colors', () {
      test('true', () async {
        await _run([
          '-Dtest_core.colors=true',
        ], contains: _generateExpectedOutput());
      });
      test('false', () async {
        await _run([
          '-Dtest_core.colors=false',
        ], contains: _generateExpectedOutput(colors: false));
      });
    });

    group('compactReporter', () {
      test('false', () async {
        await _run([
          '-Dtest_core.compactReporter=false',
        ], contains: _generateExpectedOutput());
      });
      test('true', () async {
        await _run([
          '-Dtest_core.compactReporter=true',
        ], contains: _generateExpectedOutput(compactReporter: true));
      });
    });

    group('printPath', () {
      test('false', () async {
        await _run([
          '-Dtest_core.printPath=false',
        ], contains: _generateExpectedOutput());
      });
      test('true', () async {
        await _run([
          '-Dtest_core.printPath=true',
        ], contains: _generateExpectedOutput(path: ': .'));
      });
    });

    group('printPlatform', () {
      test('false', () async {
        await _run([
          '-Dtest_core.printPlatform=false',
        ], contains: _generateExpectedOutput());
      });
      test('true', () async {
        await _run([
          '-Dtest_core.printPlatform=true',
        ], contains: _generateExpectedOutput(platform: ' [VM, Kernel]'));
      });
    });

    group('mixed', () {
      test('compactReporter, no colors', () async {
        await _run(
          ['-Dtest_core.compactReporter=true', '-Dtest_core.colors=false'],
          contains: _generateExpectedOutput(
            compactReporter: true,
            colors: false,
          ),
        );
      });
    });
  });
}

const boldCode = '\x1B[1m';
const cyanCode = '\x1B[36m';
const debugPrint = false;
const greenCode = '\x1B[32m';
const noColorCode = '\x1B[0m';
const redCode = '\x1B[31m';

String _decode(dynamic stdout) {
  if (stdout is String) {
    return stdout;
  } else {
    return systemEncoding.decoder.convert(stdout as Uint8List);
  }
}

List<Pattern> _generateExpectedOutput({
  bool colors = true,
  bool compactReporter = false,
  String path = '',
  String platform = '',
}) {
  String green(String text) => colors ? '$greenCode$text$noColorCode' : text;

  String red(String text) => colors ? '$redCode$text$noColorCode' : text;

  String bold(String text) => colors ? '$boldCode$text$noColorCode' : text;

  String cyan(String text) => colors ? '$cyanCode$text$noColorCode' : text;

  Pattern hidden(String text) => RegExp(
    '${RegExp.escape(text)}${colors ? RegExp.escape(noColorCode) : ''} +\\r',
  );

  Pattern line(
    int success,
    int fail,
    String text, {
    bool hide = false,
    bool failure = false,
    bool end = false,
  }) {
    var sb = StringBuffer();
    sb.write(green('+$success'));
    if (fail != 0) {
      sb.write(red(' $fail'));
    }
    if (end) {
      sb.write(': ${red(text)}');
    } else {
      sb.write('$path:$platform $text');
      if (failure) {
        sb.write(' ${bold(red('[E]'))}');
      }
    }
    var result = sb.toString();
    if (hide) {
      return hidden(result);
    } else {
      return result;
    }
  }

  return [
    line(0, 0, 'a', hide: compactReporter),
    line(1, 0, 'b', hide: compactReporter),
    line(1, -1, 'b', failure: true),
    if (compactReporter) cyan('To run this test again:'),
    line(1, -1, 'c', hide: compactReporter),
    line(2, -1, 'd', hide: compactReporter),
    line(2, -2, 'd', failure: true),
    if (compactReporter) cyan('To run this test again:'),
    line(2, -2, 'e', hide: compactReporter),
    line(3, -2, 'Some tests failed.', end: true),
  ];
}

Future<void> _run(
  List<String> args, {
  List<Pattern> contains = const [],
  List<String>? doesNotContain,
}) async {
  if (debugPrint) {
    print(
      '====================================================================',
    );
    print('args: $args');
  }
  var tester = File('test/scaffolding/fixtures/tester.dart');
  var result = await Process.run(Platform.executable, [
    ...args,
    tester.absolute.path,
  ]);

  var stdout = _decode(result.stdout);
  if (debugPrint) {
    print(stdout);
  }

  expect(stdout, _stringMatchesInOrder(contains));
  if (doesNotContain != null) {
    for (var text in doesNotContain) {
      expect(stdout, isNot(stringContainsInOrder([text])));
    }
  }
}

Matcher _stringMatchesInOrder(List<Pattern> substrings) =>
    _StringMatchesInOrder(substrings);

class _StringMatchesInOrder implements Matcher {
  final List<Pattern> _patterns;

  const _StringMatchesInOrder(this._patterns);

  @override
  Description describe(Description description) =>
      description.addAll('a string containing ', ', ', ' in order', _patterns);

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    var patternIndex = _matches(item, matchState);
    var pattern = _patterns[patternIndex!];
    return mismatchDescription.add(
      'Pattern #$patternIndex, $pattern, not found.',
    );
  }

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    return _matches(item, matchState) == null;
  }

  int? _matches(dynamic item, Map<dynamic, dynamic> matchState) {
    item as String;
    var fromIndex = 0;
    for (
      var patternIndex = 0;
      patternIndex < _patterns.length;
      patternIndex++
    ) {
      var s = _patterns[patternIndex];
      if (s is String) {
        var index = item.indexOf(s, fromIndex);
        if (index < 0) return patternIndex;
        fromIndex = index + s.length;
      } else {
        var matches = s.allMatches(item, fromIndex);
        if (matches.isEmpty) return patternIndex;
        fromIndex = matches.first.end;
      }
    }
    return null;
  }
}
