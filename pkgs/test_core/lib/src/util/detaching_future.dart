/// A handle on a [Future] that detaches from the original evaluation context
/// after it has resolved.
///
/// A [Future] holds the Zone it was created in and may hold references to
/// `async` functions that `await` it. When a future is stored in a static
/// variable it won't be garbage collected which means all zone variables and
/// variables in async functions get leaked. [DetachingFuture] works around this
/// by forgetting the original [Future] after it has resolved, and wrapping the
/// resolved value with `Future.value` for later calls.
///
/// https://github.com/dart-lang/sdk/issues/42457
/// https://github.com/dart-lang/sdk/issues/42458
///
/// In the case of a future that resolves to an error the original future is
/// retained.
class DetachingFuture<T> {
  T _value;
  Future<T> _inProgress;

  DetachingFuture(this._inProgress) {
    _inProgress.then((result) {
      _value = result;
      _inProgress = null;
    });
  }

  Future<T> get asFuture => _inProgress ?? Future.value(_value);
}
