## 0.1.1-wip

* Remove unused `matcher` dependency.
* Require `analyzer: '>=13.0.0 <15.0.0'`
* Import the types used as type arguments in field types, for example `Bar`
  in a field of type `List<Bar>`.
* Generate getters for function typed fields.
* Support function, record, and `Never` types in field types.
* Use the bounds for type parameters of the checked class, matching the
  extension on the raw type.
* Skip setter-only fields.
* Search the imports of the libraries declaring referenced types, in addition
  to the imports of the test library, for a library to import each type from.
  Prefer libraries outside of `src/`, and import types declared in private
  SDK libraries, such as `HttpClient`, through a public SDK library.
* Skip private fields and fields whose types reference private types, and
  report an error when `@CheckExtensions` lists a private type.
* Generate `has` calls with the field name argument before the extractor
  callback, matching `checks` `0.4.0`.

## 0.1.0

-   Initial release.
