## 1.0.0

This release contains the `FakeAsync` class that was defined in [`quiver`][].
It's backwards-compatible with both the `quiver` version *and* the old version
of the `fake_async` package.

[`quiver`]: https://pub.dartlang.org/packages/quiver

### New Features

* A top-level `fakeAsync()` function was added that encapsulates
  `new FakeAsync().run(...)`.

### New Features Relative to `quiver`

* `FakeAsync.elapsed` returns the total amount of fake time elapsed since the
  `FakeAsync` instance was created.

* `new FakeAsync()` now takes an `initialTime` argument that sets the default
  time for clocks created with `FakeAsync.getClock()`, and for the `clock`
  package's top-level `clock` variable.

### New Features Relative to `fake_async` 0.1

* `FakeAsync.periodicTimerCount`, `FakeAsync.nonPeriodicTimerCount`, and
  `FakeAsync.microtaskCount` provide visibility into the events scheduled within
  `FakeAsync.run()`.

* `FakeAsync.getClock()` provides access to fully-featured `Clock` objects based
  on `FakeAsync`'s elapsed time.

* `FakeAsync.flushMicrotasks()` empties the microtask queue without elapsing any
  time or running any timers.

* `FakeAsync.flushTimers()` runs all microtasks and timers until there are no
  more scheduled.

## 0.1.2

* Integrate with the clock package.

