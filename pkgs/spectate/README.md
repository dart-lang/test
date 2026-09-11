# package:spectate

Utilities to spy on function calls, prints, and process exit in Dart tests and code.

## Features

- **`PrintSpy`**: Intercepts and records text passed to `print()` during function execution.
  - Static methods `PrintSpy.spectate(void Function())` returning `Iterable<String>`.
  - Static methods `PrintSpy.spectateAsync(FutureOr<void> Function())` returning `Stream<String>`.
  - Function extensions `.spectatePrint` on functions with arity up to 5 (both sync and async), returning a tuple `(PrintSpy, WrappedFunction)`.
  - Instance members `prints` (all printed lines), `calls` (prints grouped by invocation), and `callCount`.

- **`CallCounter`**: Counts how many times a callback is invoked.
  - Function extensions `.countCalls` on functions with arity up to 5 (both sync and async), returning a tuple `(CallCounter, WrappedFunction)`.
  - Instance members `callCount` and `called`.

- **`ExitSpy`** (in `package:spectate/io.dart`): Intercepts and records calls to `dart:io`'s `exit()`.
  - Static methods `ExitSpy.spectate(void Function())` returning `int?`.
  - Static methods `ExitSpy.spectateAsync(FutureOr<void> Function())` returning `Future<int?>`.
  - Function extensions `.spectateExit` on functions with arity up to 5 (both sync and async), returning a tuple `(ExitSpy, WrappedFunction)`.
  - Instance members `exitCodes`, `exitCode`, `exited`, and `callCount`.
  - The main library `package:spectate/spectate.dart` does not import `dart:io` transitively, allowing use on all Dart platforms.

## Usage

### Spying on `print`

```dart
import 'package:spectate/spectate.dart';

// Spectate an inline synchronous callback:
final prints = PrintSpy.spectate(() {
  print('hello');
  print('world');
});
// prints contains ['hello', 'world']

// Spectate an inline asynchronous callback:
final printStream = PrintSpy.spectateAsync(() async {
  print('async message');
});
await for (final message in printStream) {
  print('Captured: $message');
}

// Wrap a function tear-off:
void logger(String message) {
  print('LOG: $message');
}

final (printSpy, callback) = logger.spectatePrint;
callback('first');
callback('second');

print(printSpy.prints); // ['LOG: first', 'LOG: second']
print(printSpy.callCount); // 2
print(printSpy.calls); // [['LOG: first'], ['LOG: second']]
```

### Counting Calls

```dart
import 'package:spectate/spectate.dart';

void handleEvent(int eventId) {
  // ...
}

final (counter, callback) = handleEvent.countCalls;
callback(1);
callback(2);

print(counter.callCount); // 2
print(counter.called); // true
```

### Spying on `exit`

```dart
import 'dart:io';
import 'package:spectate/io.dart';

// Spectate an inline callback:
final code = ExitSpy.spectate(() {
  exit(0);
});
print(code); // 0

// Wrap a function tear-off:
void terminate(int code) {
  exit(code);
}

final (exitSpy, callback) = terminate.spectateExit;
callback(42);

print(exitSpy.exited); // true
print(exitSpy.exitCode); // 42
```
