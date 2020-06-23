// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'package:path/path.dart' as p;
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:test/test.dart';

import '../io.dart';

void main() {
  group('spawnHybridCode()', () {

    test('can use dart:io even when run from a browser', () async {
      var path = p.join(d.sandbox, 'test.dart');
      await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("hybrid loads dart:io", () {
            expect(spawnHybridCode("""
              import 'dart:io';

              import 'package:stream_channel/stream_channel.dart';

              void hybridMain(StreamChannel channel) {
                channel.sink
                  ..add(File("$path").readAsStringSync())
                  ..close();
              }
            """).stream.first, completion(contains("hybrid emits numbers")));
          });
        }
      ''').create();

      var test = await runTest(['-p', 'chrome', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder(
              ['+0: hybrid loads dart:io', '+1: All tests passed!']));
      await test.shouldExit(0);
    }, tags: ['chrome']);

    test('forwards data from the test to the hybrid isolate', () async {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.stream.listen((num) {
            channel.sink.add(num + 1);
          });
        }
      ''');
      channel.sink..add(1)..add(2)..add(3);
      expect(channel.stream.take(3).toList(), completion(equals([2, 3, 4])));
    });

    test('passes an initial message to the hybrid isolate', () {
      var code = '''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel, Object message) {
          channel.sink..add(message)..close();
        }
      ''';

      expect(spawnHybridCode(code, message: [1, 2, 3]).stream.first,
          completion(equals([1, 2, 3])));
      expect(spawnHybridCode(code, message: {'a': 'b'}).stream.first,
          completion(equals({'a': 'b'})));
    });

    test('allows the hybrid isolate to send errors across the stream channel',
        () {
      var channel = spawnHybridCode('''
        import "package:stack_trace/stack_trace.dart";
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink.addError("oh no!", Trace.current());
        }
      ''');

      channel.stream.listen(null, onError: expectAsync2((error, stackTrace) {
        expect(error.toString(), equals('oh no!'));
        expect(stackTrace.toString(), contains('hybridMain'));
      }));
    });

    test('sends an unhandled synchronous error across the stream channel', () {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          throw "oh no!";
        }
      ''');

      channel.stream.listen(null, onError: expectAsync2((error, stackTrace) {
        expect(error.toString(), equals('oh no!'));
        expect(stackTrace.toString(), contains('hybridMain'));
      }));
    });

    test('sends an unhandled asynchronous error across the stream channel', () {
      var channel = spawnHybridCode('''
        import 'dart:async';

        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          scheduleMicrotask(() {
            throw "oh no!";
          });
        }
      ''');

      channel.stream.listen(null, onError: expectAsync2((error, stackTrace) {
        expect(error.toString(), equals('oh no!'));
        expect(stackTrace.toString(), contains('hybridMain'));
      }));
    });

    test('deserializes TestFailures as TestFailures', () {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        import "package:test/test.dart";

        void hybridMain(StreamChannel channel) {
          throw TestFailure("oh no!");
        }
      ''');

      expect(channel.stream.first, throwsA(TypeMatcher<TestFailure>()));
    });

    test('gracefully handles an unserializable message in the VM', () {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {}
      ''');

      expect(() => channel.sink.add([].iterator), throwsArgumentError);
    });

    test('gracefully handles an unserializable message in the browser',
        () async {
      await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("invalid message to hybrid", () {
            var channel = spawnHybridCode("""
              import "package:stream_channel/stream_channel.dart";

              void hybridMain(StreamChannel channel) {}
            """);

            expect(() => channel.sink.add([].iterator), throwsArgumentError);
          });
        }
      ''').create();

      var test = await runTest(['-p', 'chrome', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder(
              ['+0: invalid message to hybrid', '+1: All tests passed!']));
      await test.shouldExit(0);
    }, tags: ['chrome']);

  });
}
