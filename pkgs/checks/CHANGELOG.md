# 0.2.0

-   **Breaking Changes**
    -   `checkThat` renamed to `check`.
    -   `nest` and `nestAsync` take `Iterable<String> Function()` arguments for
        `label` instead of `String`.
    -   `matches` renamed to `matchesPattern` and now accepts a `Pattern`
        argument, instead of limiting to `RegExp`.
-   Added an example.
-   Include a stack trace in the failure description for unexpected errors from
    Futures or Streams.

# 0.1.0

-   Initial release.
