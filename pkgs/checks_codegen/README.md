[![pub package](https://img.shields.io/pub/v/checks_codegen.svg)](https://pub.dev/packages/checks_codegen)
[![package publisher](https://img.shields.io/pub/publisher/checks_codegen.svg)](https://pub.dev/packages/checks_codegen/publisher)

`package:checks_code` is a companion to [`package:checks`] for generating
extensions to read fields from subjects under test.

[`package:checks`]:https://pub.dev/packages/checks

## package:checks_codegen (experimental)

`package:checks` is still experimental. For production use cases, please use
`package:test` and `package:matcher`.

For packages in the `labs.dart.dev` publisher we generally plan to either
graduate the package into a supported publisher (`dart.dev`, `tools.dart.dev`)
after a period of feedback and iteration, or discontinue the package. These
packages have a much higher expected rate of API and breaking changes.

To provide feedback on the API, please file [an issue][] with questions,
suggestions, feature requests, or general feedback.

[an issue]:https://github.com/dart-lang/test/issues/new?labels=package%3Achecks&template=03_checks_feedback.md

## Quickstart

1. Add a `dev_dependency` on `checks_codegen` (`dart pub add
   dev:checks_codegen`).

1. In a test `some_test.dart` add an import to `some_test.checks.dart` annotated
   with `@CheckExtensions([TypesUnderTest])`.

1. Use `checks` that read fields in your test code:

```dart
@CheckExtensions([TypedData])
import 'some_test.checks.dart';

// The `elementSizeInBytes` and `lengthInBytes` extensions are generated.
void main() {
  test('sample test', () {
    check(typedData)
        ..elementSizeInBytes.equals(expectedElementSize)
        ..lengthInBytes.equals(expectedLength);
  });
}
```
