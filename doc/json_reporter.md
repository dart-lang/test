JSON Reporter Protocol
======================

The test runner supports a JSON reporter which provides a machine-readable
representation of the test runner's progress. This reporter is intended for use
by IDEs and other tools to present a custom view of the test runner's operation
without needing to parse output intended for humans.

Note that the test runner is highly asynchronous, and users of this protocol
shouldn't make assumptions about the ordering of events beyond what's explicitly
specified in this document. It's possible for events from multiple tests to be
intertwined, for a single test to emit an error after it completed successfully,
and so on.

## Usage

Pass the `--reporter json` command-line flag to the test runner to activate the
JSON reporter.

    pub run test --reporter json <path-to-test-file>

The JSON stream will be emitted via standard output. It will be a stream of JSON
objects, separated by newlines.

See `json_reporter.schema.json` for a formal description of the protocol schema.
See `test/runner/json_reporter_test.dart` for some sample output.

## Compatibility

The protocol emitted by the JSON reporter is considered part of the public API
of the `test` package, and is subject to its [semantic versioning][semver]
restrictions. In particular:

[semver]: https://www.dartlang.org/tools/pub/versioning.html#semantic-versions

* No new feature will be added to the protocol without increasing the test
  package's minor version number.

* No breaking change will be made to the protocol without increasing the test
  package's major version number.

The following changes are not considered breaking. This is not necessarily a
comprehensive list.

* Adding a new attribute to an existing object.

* Adding a new type of any object with a `type` parameter.

* Adding new test state values.

## Reading this Document

Each major type of JSON object used by the protocol is described by a class.
Classes have names which are referred to in this document, but are not used as
part of the protocol. Classes have typed attributes, which refer to the types
and names of attributes in the JSON objects. If an attribute's type is another
class, that refers to a nested object. The special type `List<...>` indicates a
JSON list of the given type.

Classes can "extend" one another, meaning that the subclass has all the
attributes of the superclass. Concrete subclasses can be distinguished by the
specific value of their `type` attribute. Classes may be abstract, indicating
that only their subclasses will ever be used.

## Events

### Event

```
abstract class Event {
  // The type of the event.
  //
  // This is always one of the subclass types listed below.
  String type;

  // The time (in milliseconds) that has elapsed since the test runner started.
  int time;
}
```

This is the root class of the protocol. All root-level objects emitted by the
JSON reporter will be subclasses of `Event`.

### StartEvent

```
class StartEvent extends Event {
  String type = "start";

  // The version of the JSON reporter protocol being used.
  //
  // This is a semantic version, but it reflects only the version of the
  // protocol—it's not identical to the version of the test runner itself.
  String protocolVersion;

  // The version of the test runner being used.
  String runnerVersion;
}
```

A single start event is emitted before any other events. It indicates that the
test runner has started running.

### AllSuitesEvent

```
class AllSuitesEvent {
  String type = "allSuites";

  /// The total number of suites that will be loaded.
  int count;
}
```

A single suite count event is emitted once the test runner knows the total
number of suites that will be loaded over the course of the test run. Because
this is determined asynchronously, its position relative to other events (except
`StartEvent`) is not guaranteed.

### SuiteEvent

```
class SuiteEvent extends Event {
  String type = "suite";

  /// Metadata about the suite.
  Suite suite;
}
```

A suite event is emitted before any `GroupEvent`s for groups in a given test
suite. This is the only event that contains the full metadata about a suite;
future events will refer to the suite by its opaque ID.

### GroupEvent

```
class GroupEvent extends Event {
  String type = "group";

  /// Metadata about the group.
  Group group;
}
```

A group event is emitted before any `TestStartEvent`s for tests in a given
group. This is the only event that contains the full metadata about a group;
future events will refer to the group by its opaque ID.

This includes the implicit group at the root of each suite, which has a `null`
name. However, it does *not* include implicit groups for the virtual suites
generated to represent loading test files.

The group should be considered skipped if `group.metadata.skip` is `true`. When
a group is skipped, a single `TestStartEvent` will be emitted for a test within
that group that will also be skipped.

### TestStartEvent

```
class TestStartEvent extends Event {
  String type = "testStart";

  // Metadata about the test that started.
  Test test;
}
```

An event emitted when a test begins running. This is the only event that
contains the full metadata about a test; future events will refer to the test by
its opaque ID.

The test should be considered skipped if `test.metadata.skip` is `true`.

### PrintEvent

```
class PrintEvent extends Event {
  String type = "print";

  // The ID of the test that printed a message.
  int testID;

  // The message that was printed.
  String message;
}
```

A `PrintEvent` indicates that a test called `print()` and wishes to display
output.

### ErrorEvent

```
class ErrorEvent extends Event {
  String type = "error";

  // The ID of the test that experienced the error.
  int testID;

  // The result of calling toString() on the error object.
  String error;

  // The error's stack trace, in the stack_trace package format.
  String stackTrace;

  // Whether the error was a TestFailure.
  bool isFailure;
}
```

A `ErrorEvent` indicates that a test encountered an uncaught error. Note
that this may happen even after the test has completed, in which case it should
be considered to have failed.

If a test is asynchronous, it may encounter multiple errors, which will result
in multiple `ErrorEvent`s.

### TestDoneEvent

```
class TestDoneEvent extends Event {
  String type = "testDone";

  // The ID of the test that completed.
  int testID;

  // The result of the test.
  String result;

  // Whether the test's result should be hidden.
  bool hidden;
}
```

An event emitted when a test completes. The `result` attribute indicates the
result of the test:

* `"success"` if the test had no errors.

* `"failure"` if the test had a `TestFailure` but no other errors.

* `"error"` if the test had an error other than a `TestFailure`.

If the test encountered an error, the `TestDoneEvent` will be emitted after the
corresponding `ErrorEvent`.

The `hidden` attribute indicates that the test's result should be hidden and not
counted towards the total number of tests run for the suite. This is true for
virtual tests created for loading test suites, `setUpAll()`, and
`tearDownAll()`. Only successful tests will be hidden.

Note that it's possible for a test to encounter an error after completing. In
that case, it should be considered to have failed, but no additional
`TestDoneEvent` will be emitted. If a previously-hidden test encounters an
error after completing, it should be made visible.

### DoneEvent

```
class DoneEvent extends Event {
  String type = "done";

  // Whether all tests succeeded (or were skipped).
  bool success;
}
```

An event indicating the result of the entire test run. This will be the final
event emitted by the reporter.

## Other Classes

### Test

```
class Test {
  // An opaque ID for the test.
  int id;

  // The name of the test, including prefixes from any containing groups.
  String name;

  // The ID of the suite containing this test.
  int suiteID;

  // The IDs of groups containing this test, in order from outermost to
  // innermost.
  List<int> groupIDs;

  // The test's metadata, including metadata from any containing groups.
  Metadata metadata;
}
```

A single test case. The test's ID is unique in the context of this test run.
It's used elsewhere in the protocol to refer to this test without including its
full representation.

Most tests will have at least one group ID, representing the implicit root
group. However, some may not; these should be treated as having no group
metadata.

### Suite

```
class Suite {
  // An opaque ID for the group.
  int id;

  // The platform on which the suite is running.
  String? platform;

  // The path to the suite's file.
  String path;
}
```

A test suite corresponding to a loaded test file. The suite's ID is unique in
the context of this test run. It's used elsewhere in the protocol to refer to
this suite without including its full representation.

A suite's platform is one of the platforms that can be passed to the
`--platform` option, or `null` if there is no platform (for example if the file
doesn't exist at all). Its path is either absolute or relative to the root of
the current package.

Suites don't include their own metadata. Instead, that metadata is present on
the root-level group.

### Group

```
class Group {
  // An opaque ID for the group.
  int id;

  // The name of the group, including prefixes from any containing groups.
  String? name;

  // The ID of the suite containing this group.
  int suiteID;

  // The ID of the group's parent group, unless it's the root group.
  int? parentID;

  // The group's metadata, including metadata from any containing groups.
  Metadata metadata;

  // The number of tests (recursively) within this group.
  int testCount;
}
```

A group containing test cases. The group's ID is unique in the context of this
test run. It's used elsewhere in the protocol to refer to this group without
including its full representation.

The implicit group at the root of each test suite has `null` `name` and
`parentID` attributes.

### Metadata

```
class Metadata {
  // Whether the test case will be skipped by the test runner.
  bool skip;

  // The reason the test case is skipped, if the user provided it.
  String? skipReason;
}
```

The metadata attached to a test by a user.
