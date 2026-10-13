

### 147. `none` as an arm of `?:`

> now fix the wart: `none` as an arm of `?:`

**Claude** fixed #116: the wrapping a `T?` or a Result gets from a
`return`, a declaration or a one-expression body now goes into each
arm of a `?:`, an arm beside one that is a `T?` is wrapped to it, and
an else arm such as `Optional<i64>(n)` is a value, not an annotation.
Details are provisional P128.

There are 663 tests, and all pass with clang and with gcc 15.
