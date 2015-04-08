`test` provides a standard way of writing and running tests in Dart.

[![Build Status](https://travis-ci.org/dart-lang/test.svg?branch=master)](https://travis-ci.org/dart-lang/test)

## Writing Tests

Tests are specified using the top-level [`test()`][test] function, and test
assertions are made using [`expect()`][expect]:

[test]: http://www.dartdocs.org/documentation/test/latest/index.html#test/test@id_test
[expect]: http://www.dartdocs.org/documentation/test/latest/index.html#test/test@id_expect

```dart
import "package:test/test.dart";

void main() {
  test("String.split() splits the string on the delimiter", () {
    var string = "foo,bar,baz";
    expect(string.split(","), equals(["foo", "bar", "baz"]));
  });

  test("String.trim() removes surrounding whitespace", () {
    var string = "  foo ";
    expect(string.trim(), equals("foo"));
  });
}
```

Tests can be grouped together using the [`group()`] function. Each group's
description is added to the beginning of its test's descriptions.

```dart
import "package:test/test.dart";

void main() {
  group("String", () {
    test(".split() splits the string on the delimiter", () {
      var string = "foo,bar,baz";
      expect(string.split(","), equals(["foo", "bar", "baz"]));
    });

    test(".trim() removes surrounding whitespace", () {
      var string = "  foo ";
      expect(string.trim(), equals("foo"));
    });
  });

  group("int", () {
    test(".remainder() returns the remainder of division", () {
      expect(11.remainder(3), equals(2));
    });

    test(".toRadixString() returns a hex string", () {
      expect(11.toRadixString(16), equals("b"));
    });
  });
}
```

Any matchers from the [`matcher`][matcher] package can be used with `expect()`
to do complex validations:

[matcher]: http://www.dartdocs.org/documentation/matcher/latest/index.html#matcher/matcher

```dart
import "package:test/test.dart";

void main() {
  test(".split() splits the string on the delimiter", () {
    expect("foo,bar,baz", allOf([
      contains("foo"),
      isNot(startsWith("bar")),
      endsWith("baz")
    ]));
  });
}
```

## Running Tests

A single test file can be run just using `dart path/to/test.dart`.

![Tests being run via "dart path/to/test.dart".](https://raw.githubusercontent.com/dart-lang/test/master/image/test1.gif)

Many tests can be run at a time using `pub run test:test path/to/dir`.

![Directory being run via "pub run".](https://raw.githubusercontent.com/dart-lang/test/master/image/test2.gif)

`test` considers any file that ends with `_test.dart` to be a test file. If
you don't pass any paths, it will run all the test files in your `test/`
directory, making it easy to test your entire application at once.

By default, tests are run in the Dart VM, but you can run them in the browser as
well by passing `pub run test:test -p chrome path/to/test.dart`.
`test` will take care of starting the browser and loading the tests, and all
the results will be reported on the command line just like for VM tests. In
fact, you can even run tests on both platforms with a single command: `pub run
test:test -p chrome -p vm path/to/test.dart`.

### Restricting Tests to Certain Platforms

Some test files only make sense to run on particular platforms. They may use
`dart:html` or `dart:io`, they might test Windows' particular filesystem
behavior, or they might use a feature that's only available in Chrome. The
[`@TestOn`][TestOn] annotation makes it easy to declare exactly which platforms
a test file should run on. Just put it at the top of your file, before any
`library` or `import` declarations:

```dart
@TestOn("vm")

import "dart:io";

import "package:test/test.dart";

void main() {
  // ...
}
```

[TestOn]: http://www.dartdocs.org/documentation/test/latest/index.html#test/test.TestOn

The string you pass to `@TestOn` is what's called a "platform selector", and it
specifies exactly which platforms a test can run on. It can be as simple as the
name of a platform, or a more complex Dart-like boolean expression involving
these platform names.

### Platform Selector Syntax

Platform selectors can contain identifiers, parentheses, and operators. When
loading a test, each identifier is set to `true` or `false` based on the current
platform, and the test is only loaded if the platform selector returns `true`.
The operators `||`, `&&`, `!`, and `? :` all work just like they do in Dart. The
valid identifiers are:

* `vm`: Whether the test is running on the command-line Dart VM.

* `chrome`: Whether the test is running on Google Chrome.

* `dart-vm`: Whether the test is running on the Dart VM in any context. For now
  this is identical to `vm`, but it will also be true for Dartium in the future.
  It's identical to `!js`.

* `browser`: Whether the test is running in any browser.

* `js`: Whether the test has been compiled to JS. This is identical to
  `!dart-vm`.

* `blink`: Whether the test is running in a browser that uses the Blink
  rendering engine.

* `windows`: Whether the test is running on Windows. If `vm` is false, this will
  be `false` as well.

* `mac-os`: Whether the test is running on Mac OS. If `vm` is false, this will
  be `false` as well.

* `linux`: Whether the test is running on Linux. If `vm` is false, this will be
  `false` as well.

* `android`: Whether the test is running on Android. If `vm` is false, this will
  be `false` as well, which means that this *won't* be true if the test is
  running on an Android browser.

* `posix`: Whether the test is running on a POSIX operating system. This is
  equivalent to `!windows`.

For example, if you wanted to run a test on every browser but Chrome, you would
write `@TestOn("browser && !chrome")`.

## Asynchronous Tests

Tests written with `async`/`await` will work automatically. The test runner
won't consider the test finished until the returned `Future` completes.

```dart
import "dart:async";

import "package:test/test.dart";

void main() {
  test("new Future.value() returns the value", () async {
    var value = await new Future.value(10);
    expect(value, equals(10));
  });
}
```

There are also a number of useful functions and matchers for more advanced
asynchrony. The [`completion()`][completion] matcher can be used to test
`Futures`; it ensures that the test doesn't finish until the `Future` completes,
and runs a matcher against that `Future`'s value.

[completion]: http://www.dartdocs.org/documentation/test/latest/index.html#test/test@id_completion

```dart
import "dart:async";

import "package:test/test.dart";

void main() {
  test("new Future.value() returns the value", () {
    expect(new Future.value(10), completion(equals(10)));
  });
}
```

The [`throwsA()`][throwsA] matcher and the various `throwsExceptionType`
matchers work with both synchronous callbacks and asynchronous `Future`s. They
ensure that a particular type of exception is thrown:

[completion]: http://www.dartdocs.org/documentation/test/latest/index.html#test/test@id_throwsA

```dart
import "dart:async";

import "package:test/test.dart";

void main() {
  test("new Future.error() throws the error", () {
    expect(new Future.error("oh no"), throwsA(equals("oh no")));
    expect(new Future.error(new StateError("bad state")), throwsStateError);
  });
}
```

The [`expectAsync()`][expectAsync] function wraps another function and has two
jobs. First, it asserts that the wrapped function is called a certain number of
times, and will cause the test to fail if it's called too often; second, it
keeps the test from finishing until the function is called the requisite number
of times.

```dart
import "dart:async";

import "package:test/test.dart";

void main() {
  test("Stream.fromIterable() emits the values in the iterable", () {
    var stream = new Stream.fromIterable([1, 2, 3]);

    stream.listen(expectAsync((number) {
      expect(number, inInclusiveRange(1, 3));
    }, count: 3));
  });
}
```

[expectAsync]: http://www.dartdocs.org/documentation/test/latest/index.html#test/test@id_expectAsync

## Testing With `barback`

Packages using the `barback` transformer system may need to test code that's
created or modified using transformers. The test runner handles this using the
`--pub-serve` option, which tells it to load the test code from a `pub serve`
instance rather than from the filesystem. **This feature is only supported on
Dart `1.9.2` and higher.**

Before using the `--pub-serve` option, add the `test/pub_serve` transformer to
your `pubspec.yaml`. This transformer adds the necessary bootstrapping code that
allows the test runner to load your tests properly:

```yaml
transformers:
- test/pub_serve:
    $include: test/**_test.dart
```

Then, start up `pub serve`. Make sure to pay attention to which port it's using
to serve your `test/` directory:

```shell
$ pub serve
Loading source assets...
Loading test/pub_serve transformers...
Serving my_app web on http://localhost:8080
Serving my_app test on http://localhost:8081
Build completed successfully
```

In this case, the port is `8081`. In another terminal, pass this port to
`--pub-serve` and otherwise invoke `pub run test` as normal:

```shell
$ pub run test --pub-serve=8081 -p chrome
"pub serve" is compiling test/my_app_test.dart...
"pub serve" is compiling test/utils_test.dart...
00:00 +42: All tests passed!
```
