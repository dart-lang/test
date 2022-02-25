Support for specifying test expectations, such as for unit tests.

The matcher library provides a third-generation assertion mechanism, drawing
inspiration from [Hamcrest](https://code.google.com/p/hamcrest/).

For more information, see
[Unit Testing with Dart](https://github.com/dart-lang/test/blob/master/pkgs/test/README.md#writing-tests).

# Best Practices

## Prefer semantically meaningful matchers to comparing derived values

Matchers which have knowledge of the semantics that are tested are able to emit
more meaningful messages which don't require reading test source to understand
why the test failed. For instance compare the failures between
`expect(someList.length, 1)`, and `expect(someList, hasLength(1))`:

```
// expect(someList.length, 1);
  Expected: <1>
    Actual: <2>
```

```
// expect(someList, hasLength(1));
  Expected: an object with length of <1>
    Actual: ['expected value', 'unexpected value']
     Which: has length of <2>

```
