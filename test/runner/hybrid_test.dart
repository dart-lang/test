// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';


import '../io.dart';

void main() {
  useSandbox();

  group("spawnHybridUri():", () {
    test("loads a file in a separate isolate connected via StreamChannel", () {
      d.file("test.dart", """
        import "package:test/test.dart";

        void main() {
          test("hybrid emits numbers", () {
            expect(spawnHybridUri("hybrid.dart").stream.toList(),
                completion(equals([1, 2, 3])));
          });
        }
      """).create();

      d.file("hybrid.dart", """
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: hybrid emits numbers",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    });

    test("resolves URIs relative to the test file", () {
      d.dir("test/dir/subdir", [
        d.file("test.dart", """
          import "package:test/test.dart";

          void main() {
            test("hybrid emits numbers", () {
              expect(spawnHybridUri("hybrid.dart").stream.toList(),
                  completion(equals([1, 2, 3])));
            });
          }
        """),

        d.file("hybrid.dart", """
          import "package:stream_channel/stream_channel.dart";

          void hybridMain(StreamChannel channel) {
            channel.sink..add(1)..add(2)..add(3)..close();
          }
        """),
      ]).create();

      var test = runTest(["test/dir/subdir/test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: hybrid emits numbers",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    });

    test("supports absolute file: URIs", () {
      var url = p.toUri(p.absolute(p.join(sandbox, 'hybrid.dart')));
      d.file("test.dart", """
        import "package:test/test.dart";

        void main() {
          test("hybrid emits numbers", () {
            expect(spawnHybridUri("$url").stream.toList(),
                completion(equals([1, 2, 3])));
          });
        }
      """).create();

      d.file("hybrid.dart", """
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: hybrid emits numbers",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    });

    test("supports Uri objects", () {
      d.file("test.dart", """
        import "package:test/test.dart";

        void main() {
          test("hybrid emits numbers", () {
            expect(spawnHybridUri(Uri.parse("hybrid.dart")).stream.toList(),
                completion(equals([1, 2, 3])));
          });
        }
      """).create();

      d.file("hybrid.dart", """
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: hybrid emits numbers",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    });

    test("rejects non-String, non-Uri objects", () {
      expect(() => spawnHybridUri(123), throwsArgumentError);
    });

    test("passes a message to the hybrid isolate", () {
      d.file("test.dart", """
        import "package:test/test.dart";

        void main() {
          test("hybrid echoes message", () {
            expect(
                spawnHybridUri(Uri.parse("hybrid.dart"), message: 123)
                    .stream.first,
                completion(equals(123)));

            expect(
                spawnHybridUri(Uri.parse("hybrid.dart"), message: "wow")
                    .stream.first,
                completion(equals("wow")));
          });
        }
      """).create();

      d.file("hybrid.dart", """
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel, Object message) {
          channel.sink..add(message)..close();
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: hybrid echoes message",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    });

    test("emits an error from the stream channel if the isolate fails to load",
        () {
      expect(spawnHybridUri("non existent file").stream.first,
          throwsA(new isInstanceOf<IsolateSpawnException>()));
    });
  });

  group("spawnHybridCode()", () {
    test("loads the code in a separate isolate connected via StreamChannel",
        () {
      expect(spawnHybridCode("""
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      """).stream.toList(), completion(equals([1, 2, 3])));
    });

    test("can use dart:io even when run from a browser", () {
      var path = p.join(sandbox, "test.dart");
      d.file("test.dart", """
        import "package:test/test.dart";

        void main() {
          test("hybrid loads dart:io", () {
            expect(spawnHybridCode('''
              import 'dart:io';

              import 'package:stream_channel/stream_channel.dart';

              void hybridMain(StreamChannel channel) {
                channel.sink
                  ..add(new File("$path").readAsStringSync())
                  ..close();
              }
            ''').stream.first, completion(contains("hybrid emits numbers")));
          });
        }
      """).create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: hybrid loads dart:io",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    }, tags: ["content-shell"]);

    test("forwards data from the test to the hybrid isolate", () {
      var channel = spawnHybridCode("""
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.stream.listen((num) {
            channel.sink.add(num + 1);
          });
        }
      """);
      channel.sink..add(1)..add(2)..add(3);
      expect(channel.stream.take(3).toList(), completion(equals([2, 3, 4])));
    });

    test("passes an initial message to the hybrid isolate", () {
      var code = """
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel, Object message) {
          channel.sink..add(message)..close();
        }
      """;

      expect(spawnHybridCode(code, message: [1, 2, 3]).stream.first,
          completion(equals([1, 2, 3])));
      expect(spawnHybridCode(code, message: {"a": "b"}).stream.first,
          completion(equals({"a": "b"})));
    });

    test("persists across multiple tests", () {
      d.file("test.dart", """
        import "dart:async";

        import "package:async/async.dart";
        import "package:stream_channel/stream_channel.dart";

        import "package:test/test.dart";

        void main() {
          StreamQueue queue;
          StreamSink sink;
          setUpAll(() {
            var channel = spawnHybridCode('''
              import "package:stream_channel/stream_channel.dart";

              void hybridMain(StreamChannel channel) {
                channel.stream.listen((message) {
                  channel.sink.add(message);
                });
              }
            ''');
            queue = new StreamQueue(channel.stream);
            sink = channel.sink;
          });

          test("echoes a number", () {
            expect(queue.next, completion(equals(123)));
            sink.add(123);
          });

          test("echoes a string", () {
            expect(queue.next, completion(equals("wow")));
            sink.add("wow");
          });
        }
      """).create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: echoes a number",
        "+1: echoes a string",
        "+2: All tests passed!"
      ]));
      test.shouldExit(0);
    }, tags: ['content-shell']);

    test("allows the hybrid isolate to send errors across the stream channel",
        () {
      var channel = spawnHybridCode("""
        import "package:stack_trace/stack_trace.dart";
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink.addError("oh no!", new Trace.current());
        }
      """);

      channel.stream.listen(null, onError: expectAsync2((error, stackTrace) {
        expect(error.toString(), equals("oh no!"));
        expect(stackTrace.toString(), contains("hybridMain"));
      }));
    });

    test("sends an unhandled synchronous error across the stream channel", () {
      var channel = spawnHybridCode("""
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          throw "oh no!";
        }
      """);

      channel.stream.listen(null, onError: expectAsync2((error, stackTrace) {
        expect(error.toString(), equals("oh no!"));
        expect(stackTrace.toString(), contains("hybridMain"));
      }));
    });

    test("sends an unhandled asynchronous error across the stream channel", () {
      var channel = spawnHybridCode("""
        import 'dart:async';

        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          scheduleMicrotask(() {
            throw "oh no!";
          });
        }
      """);

      channel.stream.listen(null, onError: expectAsync2((error, stackTrace) {
        expect(error.toString(), equals("oh no!"));
        expect(stackTrace.toString(), contains("hybridMain"));
      }));
    });

    test("deserializes TestFailures as TestFailures", () {
      var channel = spawnHybridCode("""
        import "package:stream_channel/stream_channel.dart";

        import "package:test/test.dart";

        void hybridMain(StreamChannel channel) {
          throw new TestFailure("oh no!");
        }
      """);

      expect(channel.stream.first, throwsA(new isInstanceOf<TestFailure>()));
    });

    test("gracefully handles an unserializable message in the VM", () {
      var channel = spawnHybridCode("""
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {}
      """);

      expect(() => channel.sink.add([].iterator), throwsArgumentError);
    });

    test("gracefully handles an unserializable message in the browser", () {
      d.file("test.dart", """
        import "package:test/test.dart";

        void main() {
          test("invalid message to hybrid", () {
            var channel = spawnHybridCode('''
              import "package:stream_channel/stream_channel.dart";

              void hybridMain(StreamChannel channel) {}
            ''');

            expect(() => channel.sink.add([].iterator), throwsArgumentError);
          });
        }
      """).create();

      var test = runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: invalid message to hybrid",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    }, tags: ['content-shell']);

    test("gracefully handles an unserializable message in the hybrid isolate",
        () {
      var channel = spawnHybridCode("""
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink.add([].iterator);
        }
      """);

      channel.stream.listen(null, onError: expectAsync1((error) {
        expect(error.toString(), contains("can't be JSON-encoded."));
      }));
    });

    test("forwards prints from the hybrid isolate", () {
      expect(() async {
        var channel = spawnHybridCode("""
          import "package:stream_channel/stream_channel.dart";

          void hybridMain(StreamChannel channel) {
            print("hi!");
            channel.sink.add(null);
          }
        """);
        await channel.stream.first;
      }, prints("hi!\n"));
    });

    // This takes special handling, since the code is packed into a data: URI
    // that's imported, URIs don't escape $ by default, and $ isn't allowed in
    // imports.
    test("supports a dollar character in the hybrid code", () {
      expect(spawnHybridCode(r"""
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          var value = "bar";
          channel.sink.add("foo${value}baz");
        }
      """).stream.first, completion("foobarbaz"));
    });

    test("kills the isolate when the test closes the channel", () async {
      var channel = spawnHybridCode("""
        import "dart:async";
        import "dart:io";

        import "package:shelf/shelf.dart" as shelf;
        import "package:shelf/shelf_io.dart" as io;
        import "package:stream_channel/stream_channel.dart";

        hybridMain(StreamChannel channel) async {
          var server = await ServerSocket.bind("localhost", 0);
          server.listen(null);
          channel.sink.add(server.port);
        }
      """);

      // Expect that the socket disconnects at some point (presumably when the
      // isolate closes).
      var port = await channel.stream.first;
      var socket = await Socket.connect("localhost", port);
      expect(socket.listen(null).asFuture(), completes);

      await channel.sink.close();
    }, skip: "Enable when sdk#28081 is fixed.");

    test("kills the isolate when the hybrid isolate closes the channel", () async {
      var channel = spawnHybridCode("""
        import "dart:async";
        import "dart:io";

        import "package:stream_channel/stream_channel.dart";

        hybridMain(StreamChannel channel) async {
          var server = await ServerSocket.bind("localhost", 0);
          server.listen(null);
          channel.sink.add(server.port);
          await channel.stream.first;
          channel.sink.close();
        }
      """);

      // Expect that the socket disconnects at some point (presumably when the
      // isolate closes).
      var port = await channel.stream.first;
      var socket = await Socket.connect("localhost", port);
      expect(socket.listen(null).asFuture(), completes);
      channel.sink.add(null);
    }, skip: "Enable when sdk#28081 is fixed.");

    test("closes the channel when the hybrid isolate exits", () {
      var channel = spawnHybridCode("""
        import "dart:isolate";

        hybridMain(_) {
          Isolate.current.kill();
        }
      """);

      expect(channel.stream.toList(), completion(isEmpty));
    });
  });
}
