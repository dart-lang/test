# Cross-Compiler Windows Socket Cancellation Hang

This integration package reproduces and verifies the fix for a hang on Windows
when executing concurrent test suites across different compilers and platforms
(specifically VM AOT/exe and browser suites such as Chrome).

## The Underlying Issue on Windows

The test runner communicates with native AOT test executables (`exe` compiler)
by binding a local Unix domain socket (`AF_UNIX`) via `ServerSocket.bind`,
spawning the executable with the socket path, and awaiting the incoming
connection:

```dart
var serverSocket = await ServerSocket.bind(
  InternetAddress(socketPath, type: InternetAddressType.unix),
  0,
);
var process = await _spawnExecutable(...);
var socket = await serverSocket.first;
```

On Windows, this interacts with two platform-level behaviors:

1. **Handle Inheritance**: The Dart SDK creates sockets without the
   `WSA_FLAG_NO_HANDLE_INHERIT` flag. When Dart spawns child processes
   (`Process.start`), Windows executes `CreateProcess(bInheritHandles = TRUE)`.
   Consequently, any child process spawned while a `ServerSocket` is open in the
   runner process inherits open handles to that socket.
2. **`AcceptEx` Cancellation under `afunix.sys`**: Dart's Windows event handler
   issues overlapped `AcceptEx` calls on listening sockets to detect incoming
   connections. In the Dart SDK, `Stream.first` is implemented by listening to
   the stream and awaiting `subscription.cancel()` as soon as the first element
   arrives (`_cancelAndValue`). Under Windows `afunix.sys`, pending overlapped
   `AcceptEx` requests cannot be cancelled or completed if any other running
   process holds an open handle to the socket object.

When both conditions meet, `await subscription.cancel()` hangs indefinitely
until all processes holding the inherited socket handle terminate.

## How the Race Condition Occurs

When tests run concurrently across compilers (e.g. `dart test -p chrome,vm -c dart2js,exe`):

1. **Socket Binding & Slow Compilation**: A VM executable suite
   (`vm_slow_test.dart`, importing large libraries like `package:analyzer`)
   starts loading. It binds its `ServerSocket` and begins `dart compile aot-snapshot`.
   Compilation takes several seconds.
2. **Concurrent Process Spawning**: While the VM suite is compiling and its
   `ServerSocket` remains open in the test runner process, a concurrent browser
   suite (`chrome_test.dart`) completes its fast `dart2js` compilation and spawns
   the browser process (`chrome.exe`).
3. **Handle Inheritance**: Because `chrome.exe` is spawned while the VM suite's
   `ServerSocket` handle is open in the runner, `chrome.exe` inherits the handle.
4. **Persistent Process**: `chrome.exe` remains running to execute browser tests
   or stays warm in the browser pool.
5. **Deadlock on Connection**: When the VM suite finishes compiling, its child
   process spawns and connects to the socket. `serverSocket.first` receives the
   connection and awaits `subscription.cancel()`.
6. Because `chrome.exe` holds an inherited handle to the socket,
   `subscription.cancel()` never completes. The VM suite fails with a
   `TimeoutException` during suite loading (or the entire test run hangs until
   the CI job timeout kills the browser).

## The Fix (`fastFirst`)

In `VMPlatform.load`, only the first incoming connection is needed. Instead of
awaiting `subscription.cancel()` via `Stream.first`:

```dart
extension<T> on Stream<T> {
  Future<T> get fastFirst {
    final completer = Completer<T>();
    final subscription = listen(
      completer.complete,
      onError: completer.completeError,
    );
    return completer.future..whenComplete(subscription.cancel);
  }
}
```

By completing the `Future` as soon as the socket arrives and invoking
`subscription.cancel()` unawaited, the runner can immediately begin
communicating over the connection without blocking on Windows kernel handle
cleanup.

## Reducing the Socket Listening Window

In addition to `fastFirst`, `VMPlatform.load` compiles the test suite
(via `_compileExecutable`) *before* creating the temporary directory and
binding `ServerSocket`. This eliminates the multi-second compilation window
during which the listening socket handle previously sat open in the runner
process, reducing the window from several seconds to a few milliseconds and
substantially lowering the likelihood that any concurrently spawned process
inherits the socket.
