# Unions

A union is declared, named, initialized and used as a struct is, with
C's meaning: its members share one storage, and reading a member other
than the one last written is C's type punning, with C's rules.

```kelvin
union bits { u: u64; f: f64 }

let ==(a:bits, b:bits):bool { a.u == b.u }
let bits.flipped():bits { var r = self; r.u = ~r.u; return r }

let main():i32 {
    var b:bits = {.f = 1.5}        // a designator picks the member
    var c:bits = {7}               // the first member, as in C
    println(b.u.hex, " ", b.size, " ", b == c, " ", b.flipped().u.hex)
    return 0
}
```

- **Members** are written `name: type`, ended by `;` or a new line
  *(provisional P8)*, and a union is a type by its bare name (#29):
  `var b:bits`, `sizeof(bits)`, `(bits){.f = 1.5}`; `union bits` still
  works.
- **Initializers** are `{...}`, C's: the first member, or a designated
  one, `{.f = 1.5}`. `[...]` is for arrays, and an error here.
- **`.size`** is the largest member's, padded as C pads it.
- **Text**: `b.cstr` is `<union bits>`, since kelvinc cannot tell which
  member holds the value. Define it as one template to say which:
  `let bits.cstr():cstr { `bits ${self.u.hex}` }` (#53), or show a
  member, `b.u.hex`.
- **Methods and operators** are defined on a union as on a struct: an
  implicit `self`, passed by value, and `let ==(a:bits, b:bits):bool`.
  See [structs.md](structs.md).
- **`for x in`** does not walk a union, and a union has no `.count`.
- **C unions** from headers are used as C uses them; kelvinc sees none
  of their members, so a property of one is a field there.
- **Without a tag** (#60): `union{i:i32, f:f32}` goes where a type goes,
  as `{x:f64, y:f64}` does for a struct (see [structs.md](structs.md)):
  one spelling is one type, its text is `<union{i: i32, f: f32}>`, and
  it cannot hold an owner either.
- **A union that knows its case** is `enum` with values, in
  [enums.md](enums.md) (#61).
- Not yet: a union defined inside a struct.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| a union | `.member` | a member, as C reads it |
| | `.cstr` | `<union bits>`, or `T.cstr()`'s text |
| | `.size`, `.type`, `.typename` | the largest member's size; the type; its name or spelling |
| | `.method(...)`, operators | as a struct's |

A union holds no owner, so it has no `.copy()`. An enum with values,
which knows its case, is in [enums.md](enums.md).
