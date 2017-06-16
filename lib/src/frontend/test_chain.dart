import 'package:stack_trace/stack_trace.dart';

typedef StackTrace Mapper(StackTrace trace);

/// Converts [trace] into a Dart stack trace
Mapper currentMapper = (trace) => trace;

/// The list of packages to fold when producing [StackTrace]s.
Set<String> exceptPackages = new Set.from(['test', 'stream_channel']);

/// If non-empty, all packages not in this list will be folded when producing
/// [StackTrace]s.
Set<String> onlyPackages = new Set();

/// Converts [stackTrace] to a [Chain] following the test's configuration.
Chain testChain(StackTrace stackTrace, {bool verbose: false}) {
  var testTrace = currentMapper(stackTrace);
  if (verbose) return new Chain.forTrace(testTrace);
  return new Chain.forTrace(testTrace).foldFrames((frame) {
    if (onlyPackages.isNotEmpty) {
      return !onlyPackages.contains(frame.package);
    }
    return exceptPackages.contains(frame.package);
  }, terse: true);
}
