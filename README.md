Support for writing unit tests in Dart.

**See also:**
[Unit Testing with Dart]
(http://www.dartlang.org/articles/dart-unit-tests/)

##Concepts

 * __Tests__: Tests are specified via the top-level function [test], they can be
   organized together using [group].

 * __Checks__: Test expectations can be specified via [expect]

 * __Matchers__: [expect] assertions are written declaratively using the
   [Matcher] class.

 * __Configuration__: The framework can be adapted by setting
   [unittestConfiguration] with a [Configuration]. See the other libraries
   in the `unittest` package for alternative implementations of
   [Configuration] including `compact_vm_config.dart`, `html_config.dart`
   and `html_enhanced_config.dart`.

##Examples

A trivial test:

```dart
import 'package:unittest/unittest.dart';

void main() {
  test('this is a test', () {
    int x = 2 + 3;
    expect(x, equals(5));
  });
}
```

Multiple tests:

```dart
import 'package:unittest/unittest.dart';

void main() {
  test('this is a test', () {
    int x = 2 + 3;
    expect(x, equals(5));
  });
  test('this is another test', () {
    int x = 2 + 3;
    expect(x, equals(5));
  });
}
```

Multiple tests, grouped by category:

```dart
import 'package:unittest/unittest.dart';

void main() {
  group('group A', () {
    test('test A.1', () {
      int x = 2 + 3;
      expect(x, equals(5));
    });
    test('test A.2', () {
      int x = 2 + 3;
      expect(x, equals(5));
    });
  });
  group('group B', () {
    test('this B.1', () {
      int x = 2 + 3;
      expect(x, equals(5));
    });
  });
}
```

Asynchronous tests: if callbacks expect between 0 and 6 positional
arguments, [expectAsync] will wrap a function into a new callback and will
not consider the test complete until that callback is run. A count argument
can be provided to specify the number of times the callback should be called
(the default is 1).

```dart
import 'dart:async';
import 'package:unittest/unittest.dart';

void main() {
  test('callback is executed once', () {
    // wrap the callback of an asynchronous call with [expectAsync] if
    // the callback takes 0 arguments...
    Timer.run(expectAsync(() {
      int x = 2 + 3;
      expect(x, equals(5));
    }));
  });

  test('callback is executed twice', () {
    var callback = expectAsync(() {
      int x = 2 + 3;
      expect(x, equals(5));
    }, count: 2); // <-- we can indicate multiplicity to [expectAsync]
    Timer.run(callback);
    Timer.run(callback);
  });
}
```

There may be times when the number of times a callback should be called is
non-deterministic. In this case a dummy callback can be created with
expectAsync((){}) and this can be called from the real callback when it is
finally complete.

A variation on this is [expectAsyncUntil], which takes a callback as the
first parameter and a predicate function as the second parameter. After each
time the callback is called, the predicate function will be called. If it
returns `false` the test will still be considered incomplete.

Test functions can return [Future]s, which provide another way of doing
asynchronous tests. The test framework will handle exceptions thrown by
the Future, and will advance to the next test when the Future is complete.

```dart
import 'dart:async';
import 'package:unittest/unittest.dart';

void main() {
  test('test that time has passed', () {
    var duration = const Duration(milliseconds: 200);
    var time = new DateTime.now();

    return new Future.delayed(duration).then((_) {
      var delta = new DateTime.now().difference(time);

      expect(delta, greaterThanOrEqualTo(duration));
    });
  });
}
```
