The `test_descriptor` package provides a convenient, easy-to-read API for
defining and verifying directory structures in tests.

We recommend that you import this library with the `d` prefix. The
[`d.dir()`][dir] and [`d.file()`][file] functions are the main entrypoints. They
define a filesystem structure that can be created using
[`Descriptor.create()`][create] and verified using
[`Descriptor.validate()`][validate]. For example:

[dir]: https://www.dartdocs.org/documentation/test_descriptor/latest/test_descriptor/dir.html
[file]: https://www.dartdocs.org/documentation/test_descriptor/latest/test_descriptor/file.html
[create]: https://www.dartdocs.org/documentation/test_descriptor/latest/test_descriptor/Descriptor/create.html
[validate]: https://www.dartdocs.org/documentation/test_descriptor/latest/test_descriptor/Descriptor/validate.html

```dart
import 'dart:io';

import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test("Directory.rename", () async {
    await d.dir("parent", [
      d.file("sibling", "sibling-contents"),
      d.dir("old-name", [
        d.file("child", "child-contents")
      ])
    ]).create();

    await new Directory("${d.sandbox}/parent/old-name")
        .rename("${d.sandbox}/parent/new-name");

    await d.dir("parent", [
      d.file("sibling", "sibling-contents"),
      d.dir("new-name", [
        d.file("child", "child-contents")
      ])
    ]).validate();
  });
}
```

By default, descriptors create entries in a temporary sandbox directory,
[`d.sandbox`][sandbox]. A new sandbox is automatically created the first time
you create a descriptor in a given test, and automatically deleted once the test
finishes running.

[sandbox]: https://www.dartdocs.org/documentation/test_descriptor/latest/test_descriptor/sandbox.html

This package is [`term_glyph`][term_glyph] aware. It will decide whether to use
ASCII or Unicode glyphs based on the [`glyph.ascii`][glyph.ascii] attribute.

[term_glyph]: https://pub.dartlang.org/packages/term_glyph
[gylph.ascii]: https://www.dartdocs.org/documentation/term_glyph/latest/term_glyph/ascii.html
