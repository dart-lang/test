`unittest` provides a standard way of writing and running tests in Dart.

## Writing Tests

Tests are specified using the top-level [`test()`][test] function, and test
assertions are made using [`expect()`][expect]:

[test]: http://www.dartdocs.org/documentation/unittest/latest/index.html#unittest/unittest@id_test
[expect]: http://www.dartdocs.org/documentation/unittest/latest/index.html#unittest/unittest@id_expect

```dart
import "package:unittest/unittest.dart";

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
import "package:unittest/unittest.dart";

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
import "package:unittest/unittest.dart";

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

![Tests being run via "dart path/to/test.dart".](https://raw.githubusercontent.com/dart-lang/unittest/master/image/test1.gif)

Many tests can be run at a time using `pub run unittest:unittest path/to/dir`.

![Directory being run via "pub run".](https://raw.githubusercontent.com/dart-lang/unittest/master/image/test2.gif)

`unittest` considers any file that ends with `_test.dart` to be a test file. If
you don't pass any paths, it will run all the test files in your `test/`
directory, making it easy to test your entire application at once.

By default, tests are run in the Dart VM, but you can run them in the browser as
well by passing `pub run unittest:unittest -p chrome path/to/test.dart`.
`unittest` will take care of starting the browser and loading the tests, and all
the results will be reported on the command line just like for VM tests. In
fact, you can even run tests on both platforms with a single command: `pub run
unittest:unittest -p chrome -p vm path/to/test.dart`.

## Asynchronous Tests

Tests written with `async`/`await` will work automatically. The test runner
won't consider the test finished until the returned `Future` completes.

```dart
import "dart:async";

import "package:unittest/unittest.dart";

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

[completion]: http://www.dartdocs.org/documentation/unittest/latest/index.html#unittest/unittest@id_completion

```dart
import "dart:async";

import "package:unittest/unittest.dart";

void main() {
  test("new Future.value() returns the value", () {
    expect(new Future.value(10), completion(equals(10)));
  });
}
```

The [`throwsA()`][throwsA] matcher and the various `throwsExceptionType`
matchers work with both synchronous callbacks and asynchronous `Future`s. They
ensure that a particular type of exception is thrown:

[completion]: http://www.dartdocs.org/documentation/unittest/latest/index.html#unittest/unittest@id_throwsA

```dart
import "dart:async";

import "package:unittest/unittest.dart";

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

import "package:unittest/unittest.dart";

void main() {
  test("Stream.fromIterable() emits the values in the iterable", () {
    var stream = new Stream.fromIterable([1, 2, 3]);

    stream.listen(expectAsync((number) {
      expect(number, inInclusiveRange(1, 3));
    }, count: 3));
  });
}
```

[expectAsync]: http://www.dartdocs.org/documentation/unittest/latest/index.html#unittest/unittest@id_expectAsync
