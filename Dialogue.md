

### 146. The `?` before `in`, and `"""`

> now fix the wart: `):JSON? in` in an anonymous function. Also add the
> multi-line, non-interpolating `"""` a la python, et al. That may quote
> JSON-like text more easily.

**Claude** fixed #114: the signature lookahead stopped at the `?` of a
base type and took `in` for an operand, and a one-expression body of a
`T?` result was not wrapped as `return` wraps it; both now are, so
`{ (key:cstr, v:const JSON^):JSON? in none }` is a replacer. And added
#115: `"""text"""`, a string literal over lines with the text as it
is, no escapes and no `${...}`, so `JSON.parse("""{"a": "b\n"}""")`
reads JSON as written. Details are provisional P126 and P127.

There are 662 tests, and all pass with clang and with gcc 15.
