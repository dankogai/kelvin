# Properties

A property is written after a value with no parentheses, and gives its
size, its type, its text, or, for a pointer, its address and whether it
is null. This document has the ones every value shares, and their
details. Each type's own are listed, with its methods, at the end of
its document:

| Type | Synopsis |
|---|---|
| numbers, `bool` | [integers.md](integers.md#properties-and-methods) |
| pointers | [pointers.md](pointers.md#properties-and-methods) |
| `cstr`, `Bytes`, `String`, `uchr` | [cstrings.md](cstrings.md#properties-and-methods) |
| arrays, `Array<T>` | [arrays.md](arrays.md#properties-and-methods) |
| structs | [structs.md](structs.md#properties-and-methods) |
| unions | [unions.md](unions.md#properties-and-methods) |
| enums, enums with values | [enums.md](enums.md#properties-and-methods) |
| `Dictionary<K, V>` | [dictionaries.md](dictionaries.md#properties-and-methods) |
| functions | [functions.md](functions.md#properties-and-methods) |

## `.size`, `.count`, `.type`, `.typename`, `.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.addr`, `.isNull`

Properties are written without parentheses:

```kelvin
let c:i32 = 42
let b:u8 = 255
let p:point = {3, 4}
println(c.size, " ", c.cstr, " ", p.cstr)   // 4 42 {x: 3, y: 4}
println(c.dec, " ", c.hex, " ", c.bin)      // +42 +0x2a +0b101010
println(b.dec, " ", b.hex, " ", b.oct)      // 255 0xff 0o377
println(3.141592653589793.hex)              // +0x1.921fb54442d18p+1
```

- **`x.size`** is `sizeof(x)`. A function's `.size`, and its `sizeof`,
  are a pointer's size, since its name is a function value (#31).
- **`a.count`** is an array's number of elements (#49), `a.size` its
  bytes; see [arrays.md](arrays.md). A `cstr`'s `.count` is its
  `strlen` (#52); a `String`'s its codepoints (#55).
- **`c.utf32`** and **`c.codepoint`** are a `uchr`'s number, a `u32`,
  and **`n.uchr`** an integer's codepoint (#56); see
  [ownership.md](ownership.md).
- **`v.type`** is `v`'s type, written where a type goes (#34): after `:`
  and `as`, in `sizeof(...)`, in compound literals and in function types.
  `v` is a variable or `$k`, possibly followed by `.member`, `^` and
  `[i]`, as in `var w:k.type = 4`, `let p := &w as w.type^` or
  `pp^.y.type`.
  - It is the type kelvinc sees `v` declared with, so a `let`'s own
    `const` does not come along (`var w:k.type` can change). A `const`
    written before it, as in `const xs.type`, applies to an array's
    elements, as in C.
  - Where kelvinc cannot see the type (a name from a C header), or the
    type holds something C would evaluate again (a length that is not a
    number, as in a variable length array), it is C's `__typeof__(v)`,
    which keeps `v`'s own length and also a `let`'s `const`. For a C
    function, that is C's function type; `f.type^` is its pointer.
  - In `sizeof(x.type)` and `(x.type)`, where an expression could stand
    too, `.type` is a field when `x` has one, is a C struct, or has a type
    kelvinc cannot see; write `x.type` after `:` or `as` there. In other
    expressions, `x.type` is a field if `x` may have one, and otherwise an
    error, as a type is not a value.
  - A result type cannot name a parameter (C writes the result first),
    and `point.type` of a type or `i64.type` asks for the type itself.
  - A variable used only for its `.type` or `.typename` is unused as far
    as C sees (`-Wunused-variable` under `-Wall`) *(provisional P45)*.
- **`v.typename`** is the text of `v`'s type as Kelvin writes it, a `cstr`:
  `"i64"`, `"point"`, `"u8^"`, `"[i32](4)"`, `"(i64):i64"`,
  `"((i64):i64)^"`. Where kelvinc cannot see the type, or it holds a
  `__typeof__`, C's `_Generic` gives the Kelvin name of a built-in type
  (`getenv("X").typename` is `"u8^"`), and anything else is `"?"`. A
  literal is C's: `42.typename` is `"i32"`, as `42.size` is 4, and
  `nullptr.typename` is `"any^"`. Through `_Generic`, an array is a
  pointer, an enum its integer type, and a bit-field may differ between
  compilers. `v` is not evaluated, as for `sizeof`.
- **`x.cstr`** is the text of any value, as `cstr` (#22):
  - **Numbers** are plain decimal (`42`, `-7`), including 128-bit ones.
    Floats are lossless: `0.1.cstr` is `0.10000000000000001` (`%.17g`;
    `%.9g` for `f32`), while `print` keeps the shortest form, `0.1`.
  - **`bool`** is `true` or `false`. **C's `_Complex` numbers** are
    `1+2i`; `complex64` and `complex32` of modules/complex.k are structs,
    `{real: 1, imag: 2}`.
  - **A string** (`cstr`, `u8^`, `i8^`, a literal) is its own text:
    `s.cstr` is `s` itself, still `const` if `s` was. Other pointers are
    addresses (`0x0` for null), but a function has no text (#31).
  - **Structs** get derived text, `{x: 3, y: 4}`, with nested structs and
    arrays (`[a, b]`); a string field shows at most 60 bytes, and a longer
    one is cut with `...` *(provisional P35)*. A union is `<union name>`.
    A struct or union may define its own, `let T.cstr():cstr { `...` }`,
    one template literal (#53); see [structs.md](structs.md).
  - **Arrays** have no `.cstr` (C arrays are not values); index them, or
    put them in a struct.
  - **C structs and unions** from headers have no `.cstr` of their own.
    Inside a Kelvin struct they show as `{...}`, as do other C types
    kelvinc cannot print: arrays other than `char` text, and pointers
    behind a typedef other than byte strings and `void *` (a function
    pointer, `pthread_t` on macOS). A struct whose flexible array member
    is declared through a C typedef has no `.cstr`.
  - **Where kelvinc cannot see that a value is a struct**, as in
    `(q, p).cstr`, the C compiler reports `kv_cstr_unseen_struct`;
    assign the value to a variable first. kelvinc does see variables,
    fields, `v as T`, what Kelvin functions and methods return (not a
    call that C chooses among overloads with different results), and a
    `?:` between two values of one type (#34) *(provisional P35)*.
- **`cstr`** is immutable text, C's `const uint8_t *` (#52): a
  reference, assigned with `:=`, that cannot be written through or
  stepped; `s.count` is `strlen(s)`, measured once per scope. See
  [cstrings.md](cstrings.md) *(provisional P36, P64)*.
- **Integers** have `.dec`, `.hex`, `.oct` and `.bin`. Each returns `u8^`
  text with a prefix of `0x`, `0o` or `0b`. Signed integers always carry a
  sign (`+42`, `-0x2a`) and unsigned ones never do, so the text tells
  `i32` from `u32`.
- **`f32`/`f64`** have `.dec` (lossless, like `.cstr`) and `.hex`
  (C's `%a`), always signed.
- **Pointers and functions** have `.addr` and `.hex` (#37). `p.addr` is
  the address as a number, a `uintptr_t` (C's unsigned integer as wide
  as a pointer), and `p.hex` its text: `0x` and all the digits, 16 on a
  64-bit target (`0x000000016ee86888`), with no sign, so every address
  has the same width and `u64(p.hex, 16)` is `p.addr`. This covers
  every `T^`, `any^`, `cstr`, string literal, `nullptr` and function
  value, `&x`, the text of a property (`n.hex.addr`), a pointer stepped
  with `+` or `-`, and a `?:` of pointers. Where only C's `_Generic`
  sees that a value is a pointer (`getenv("X")`), `.hex` still works,
  but `.addr` is a field there, as `.size` is: write `x as uintptr_t`.
  An array is no pointer: write `(&a[0]).addr`.
  Through `_Generic`,
  though, an array kelvinc cannot see (a C struct's `char` array field)
  is a pointer, so its `.hex` is its first element's address. Pointers
  have no `.dec`, `.oct` or `.bin`, and `.cstr` is as before: a string's
  own text, another pointer's `%p`-like text (`0x16ee86888`), and none
  for a function *(provisional P48)*.
- **Pointers and functions** also have `.isNull` (#50): `p.isNull` is
  `p == nullptr`, a `bool`, so `if p.isNull { }` and `while !f.isNull { }`
  read as they sound. It covers every pointer and function value
  kelvinc sees, `nullptr` included; a struct's field named `isNull`
  wins, and a value only C sees keeps its field, as with `.addr`, so
  there write `== nullptr`. An array is never null, so `a.isNull` is an
  error *(provisional P62)*.
- **The text lives on the caller's stack**, in a buffer sized in advance:
  for `.dec` and friends, to fit the text of any type (at most 132 bytes,
  for `.bin`); for `.cstr`, from the receiver's struct, or 64 bytes for
  one value. There is no heap and nothing to free. The text lasts until the enclosing block
  ends, also when it was made in a brace-less `for` body or among
  a method call's arguments. Do not return it from a function
  *(provisional P34)*.
- **Fields win.** A field with the same name wins, in a Kelvin struct and
  in a C struct from a header. When kelvinc cannot see whether the
  receiver is a struct, `.size`, `.type`, `.addr` and the converters
  such as `.i64` are fields (write `sizeof(x)`, `var y:x.type`,
  `x as uintptr_t` or `i64(x)` there), while `.cstr`/`.dec`/`.hex`/`.oct`/`.bin` are
  properties. `.typename` is a property also of a C struct, since C++
  reserves the word and C headers rarely name a field so (#34).
- **Errors.** `.hex` on a bool or struct, `.dec`, `.oct` or `.bin` on a
  pointer, and `.oct` or `.bin` on a float, are errors. Where kelvinc
  cannot see the type, as in `getenv("HOME").oct` or `div(7, 2).hex`,
  the C compiler reports it, naming `kv_no_such_property`.
- **Enums** follow C's types. An enumerator such as `BLUE` is an `int`,
  so `BLUE.dec` is `+2`. A variable of an enum type has the integer type
  the C compiler picks, `unsigned int` on gcc and clang when no
  enumerator is negative, so its `.dec` is `2`.
- **C bit-fields** from a header are converted first, as in
  `u32(b.flags).hex`: gcc's `_Generic` does not match a bit-field's type.

