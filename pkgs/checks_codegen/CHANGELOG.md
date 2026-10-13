## 0.1.1-wip

* Require `analyzer: '>=13.0.0 <15.0.0'`
* Import the types used as type arguments in field types, for example `Bar`
  in a field of type `List<Bar>`.
* Generate getters for function typed fields.
* Support function, record, and `Never` types in field types.
* Use the bounds for type parameters of the checked class, matching the
  extension on the raw type.
* Skip setter-only fields.

 
## 0.1.0

-   Initial release.
