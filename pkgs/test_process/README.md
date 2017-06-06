A library for testing subprocesses.

This exposes a [`TestProcess`][TestProcess] class that wraps `dart:io`'s
[`Process`][Process] class and makes it easy to read standard output
line-by-line. `TestProcess` works the same as `Process` in many ways, but there
are a few major differences.

[TestProcess]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess-class.html
[Process]: https://api.dartlang.org/stable/latest/dart-io/Process-class.html

## Standard Output

`Process.stdout` and `Process.stderr` are binary streams, which is the most
general API but isn't the most helpful when working with a program that produces
plain text. Instead, [`TestProcess.stdout`][stdout] and
[`TestProcess.stderr`][stderr] emit a string for each line of output the process
produces. What's more, they're [`StreamQueue`][StreamQueue]s, which means
they provide a *pull-based API*. For example:

[stdout]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess/stdout.html
[stderr]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess/stderr.html
[StreamQueue]: https://www.dartdocs.org/documentation/async/latest/async/StreamQueue-class.html

```dart
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

void main() {
  test("pub get gets dependencies", () async {
    // TestProcess.start() works just like Process.start() from dart:io.
    var process = await TestProcess.start("pub", ["get"]);

    // StreamQueue.next returns the next line emitted on standard out.
    var firstLine = await process.stdout.next;
    expect(firstLine, equals("Resolving dependencies..."));

    // Each call to StreamQueue.next moves one line further.
    String next;
    do {
      next = await process.stdout.next;
    } while (next != "Got dependencies!");

    // Assert that the process exits with code 0.
    await process.shouldExit(0);
  });
}
```

The `test` package's [stream matchers][] have built-in support for
`StreamQueues`, which makes them perfect for making assertions about a process's
output. We can use this to clean up the previous example:

[stream matchers]: https://github.com/dart-lang/test#stream-matchers

```dart
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

void main() {
  test("pub get gets dependencies", () async {
    var process = await TestProcess.start("pub", ["get"]);

    // Each stream matcher will consume as many lines as it matches from a
    // StreamQueue, and no more, so it's safe to use them in sequence.
    await expectLater(process.stdout, emits("Resolving dependencies..."));

    // The emitsThrough matcher matches and consumes any number of lines, as
    // long as they end with one matching the argument.
    await expectLater(process.stdout, emitsThrough("Got dependencies!"));

    await process.shouldExit(0);
  });
}
```

If you want to access the standard output streams without consuming any values
from the queues, you can use the [`stdoutStream()`][stdoutStream] and
[`stderrStream()`][stderrStream] methods. Each time you call one of these, it
produces an entirely new stream that replays the corresponding output stream
from the beginning, regardless of what's already been produced by `stdout`,
`stderr`, or other calls to the stream method.

[stdoutStream]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess/stdoutStream.html
[stderrStream]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess/stderrStream.html

## Signals and Termination

The way signaling works is different from `dart:io` as well. `TestProcess` still
has a [`kill()`][kill] method, but it defaults to `SIGKILL` on Mac OS and Linux
to ensure (as best as possible) that processes die without leaving behind
zombies. If you want to send a particular signal (which is unsupported on
Windows), you can do so by explicitly calling [`signal()`][signal].

[kill]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess/kill.html
[signal]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess/signal.html

In addition to [`exitCode`][exitCode], which works the same as in `dart:io`,
`TestProcess` also adds a new method named [`shouldExit()`][shouldExit]. This
lets tests wait for a process to exit, and (if desired) assert what particular
exit code it produced.

[exitCode]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess/exitCode.html
[shouldExit]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess/shouldExit.html

## Debugging Output

When a test using `TestProcess` fails, it will print all the output produced by
that process. This makes it much easier to figure out what went wrong and why.
The debugging output uses a header based on the process's invocation by
default, but you can pass in custom `description` parameters to
[`TestProcess.start()`][start] to control the headers.

[start]: https://www.dartdocs.org/documentation/test_process/latest/test_process/TestProcess/start.html

`TestProcess` will also produce debugging output as the test runs if you pass
`forwardStdio: true` to `TestProcess.start()`. This can be particularly useful
when you're using an interactive debugger and you want to figure out what a
process is doing before the test finishes and the normal debugging output is
printed.
