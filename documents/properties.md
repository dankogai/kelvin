# Properties

A property is written after a value with no parentheses, and gives its
size, its type, its text, or, for a pointer, its address and whether it
is null. This document has the ones every value shares, and their
details, and how a type of your own gets its own attributes, alone or
in an `extend T { }` block (see
[Attributes of your own](#attributes-of-your-own-and-extend)). Each
type's own are listed, with its methods, at the end of its document:


| Type | Synopsis |
|---|---|
| integers | [integers.md](integers.md#properties-and-methods) |
| `f32`, `f64` | [floatingpoint.md](floatingpoint.md#properties-and-methods) |
| `bool` | [bool.md](bool.md#properties-and-methods) |
| pointers | [pointers.md](pointers.md#properties-and-methods) |
| `cstr`, `Bytes`, `String`, `uchr` | [strings.md](strings.md#properties-and-methods) |
| arrays, `Array<T>` | [arrays.md](arrays.md#properties-and-methods) |
| structs | [structs.md](structs.md#properties-and-methods) |
| unions | [unions.md](unions.md#properties-and-methods) |
| enums, enums with values | [enums.md](enums.md#properties-and-methods) |
| `Dictionary<K, V>` | [dictionaries.md](dictionaries.md#properties-and-methods) |
| `Set<T>` | [sets.md](sets.md#properties-and-methods) |
| `Result<T, U>` | [results.md](results.md#properties-and-methods) |
| `T?` | [optionals.md](optionals.md#properties-and-methods) |
| `IO` | [io.md](io.md#properties-and-methods) |
| `OS`, `SYS` | [os.md](os.md#properties-and-methods) |
| functions | [functions.md](functions.md#properties-and-methods) |

**Where it lives:** `.size`, `.type`, `.typename`, `.addr` and `.isNull` are the core, written as C's `sizeof`, `__typeof__` and comparisons. `.cstr`, `.dec`, `.hex`, `.oct` and `.bin` write their text with the prelude's functions, in `libkelvin`, linked without an import.

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
  bytes; see [arrays.md](arrays.md).
  - A `cstr`'s `.count` is its `strlen` (#52); a `String`'s its
    codepoints (#55).
- **`c.utf32`** and **`c.codepoint`** are a `uchr`'s number, a `u32`,
  and **`n.uchr`** an integer's codepoint (#56); see
  [ownership.md](ownership.md).
- **`v.type`** is `v`'s type, written where a type goes (#34): after `:`
  and `as`, in `sizeof(...)`, in compound literals and in function types.
  - `v` is a variable or `$k`, possibly followed by `.member`, `^` and
    `[i]`, as in `var w:k.type = 4`, `let p := &w as w.type^` or
    `pp^.y.type`.
  - It is the type kelvinc sees `v` declared with, so a `let`'s own
    `const` does not come along (`var w:k.type` can change).
    - A `const` written before it, as in `const xs.type`, applies to an
      array's elements, as in C.
  - Where kelvinc cannot see the type (a name from a C header), or the
    type holds something C would evaluate again (a length that is not a
    number, as in a variable length array), it is C's `__typeof__(v)`,
    which keeps `v`'s own length and also a `let`'s `const`.
    - For a C function, that is C's function type; `f.type^` is its
      pointer.
  - In `sizeof(x.type)` and `(x.type)`, where an expression could stand
    too, `.type` is a field when `x` has one, is a C struct, or has a
    type kelvinc cannot see; write `x.type` after `:` or `as` there.
    - In other expressions, `x.type` is a field if `x` may have one, and
      otherwise an error, as a type is not a value.
  - A result type cannot name a parameter (C writes the result first),
    and `point.type` of a type or `i64.type` asks for the type itself.
  - A variable used only for its `.type` or `.typename` is unused as far
    as C sees (`-Wunused-variable` under `-Wall`) *(provisional P45)*.
- **`v.typename`** is the text of `v`'s type as Kelvin writes it, a
  `cstr`: `"i64"`, `"point"`, `"u8^"`, `"[i32](4)"`, `"(i64):i64"`,
  `"((i64):i64)^"`.
  - Where kelvinc cannot see the type, or it holds a `__typeof__`, C's
    `_Generic` gives the Kelvin name of a built-in type
    (`getenv("X").typename` is `"u8^"`), and anything else is `"?"`.
  - A literal is C's: `42.typename` is `"i32"`, as `42.size` is 4, and
    `nullptr.typename` is `"any^"`.
  - Through `_Generic`, an array is a pointer, an enum its integer type,
    and a bit-field may differ between compilers.
  - `v` is not evaluated, as for `sizeof`.
- **`x.cstr`** is the text of any value, as `cstr` (#22):
  - **Numbers** are plain decimal (`42`, `-7`), including 128-bit ones.
    Floats are lossless: `0.1.cstr` is `0.10000000000000001` (`%.17g`;
    `%.9g` for `f32`), while `print` keeps the shortest form, `0.1`.
  - **`bool`** is `true` or `false`.
  - **C's `_Complex` numbers** are `1+2i`; `complex64` and `complex32`
    of modules/complex.k are structs, `{real: 1, imag: 2}`.
  - **A string** (`cstr`, `u8^`, `i8^`, a literal) is its own text:
    `s.cstr` is `s` itself, still `const` if `s` was. Other pointers are
    addresses (`0x0` for null), but a function has no text (#31).
  - **Structs** get derived text, `{x: 3, y: 4}`, with nested structs
    and arrays (`[a, b]`).
    - A string field is quoted, `{name: "ann"}` (#123), and shows at
      most 60 bytes; a longer one is cut with `..."`
      *(provisional P35)*.
    - An `Array` field is `[...]`, a `Dictionary` or a `Set` field
      `{...}`: `print` shows them whole (#123).
    - A union is `<union name>`.
    - A struct or union may define its own,
      `let T.cstr():cstr { `...` }`, one template literal (#53); see
      [structs.md](structs.md).
  - **Arrays** have no `.cstr` (C arrays are not values); index them, or
    put them in a struct. An `Array<T>`, a `Dictionary` and a `Set` have
    none either: `print` shows them, and `.pretty` is their text.
- **`x.pretty`** (#124) is the text of a struct, an enum with values, an
  Optional, a Result, an Array, a Dictionary or a Set, indented, a line
  for each item of a `[]` or `{}`: printed where `print` shows it, a
  `String` elsewhere; see [printing.md](printing.md). **`x.pretty(n)`**
  (#127) indents `n` spaces a level, 0 to 10; `x.pretty` is two.
  - **C structs and unions** from headers have no `.cstr` of their own.
    - Inside a Kelvin struct they show as `{...}`, as do other C types
      kelvinc cannot print: arrays other than `char` text, and pointers
      behind a typedef other than byte strings and `void *` (a function
      pointer, `pthread_t` on macOS).
    - A struct whose flexible array member is declared through a C
      typedef has no `.cstr`.
  - **Where kelvinc cannot see that a value is a struct**, as in
    `(q, p).cstr`, the C compiler reports `kv_cstr_unseen_struct`;
    assign the value to a variable first.
    - kelvinc does see variables, fields, `v as T`, what Kelvin
      functions and methods return (not a call that C chooses among
      overloads with different results), and a `?:` between two values
      of one type (#34) *(provisional P35)*.
- **`cstr`** is immutable text, C's `const uint8_t *` (#52): a
  reference, assigned with `:=`, that cannot be written through or
  stepped.
  - `s.count` is `strlen(s)`, measured once per scope.
  - See [strings.md](strings.md) *(provisional P36, P64)*.
- **Integers** have `.dec`, `.hex`, `.oct` and `.bin`. Each returns
  `u8^` text with a prefix of `0x`, `0o` or `0b`.
  - Signed integers always carry a sign (`+42`, `-0x2a`) and unsigned
    ones never do, so the text tells `i32` from `u32`.
- **`f32`/`f64`** have `.dec` (lossless, like `.cstr`) and `.hex`
  (C's `%a`), always signed.
- **Pointers and functions** have `.addr` and `.hex` (#37).
  - `p.addr` is the address as a number, a `uintptr_t` (C's unsigned
    integer as wide as a pointer).
  - `p.hex` is its text: `0x` and all the digits, 16 on a 64-bit target
    (`0x000000016ee86888`), with no sign, so every address has the same
    width and `u64(p.hex, 16)` is `p.addr`.
  - This covers every `T^`, `any^`, `cstr`, string literal, `nullptr`
    and function value, `&x`, the text of a property (`n.hex.addr`), a
    pointer stepped with `+` or `-`, and a `?:` of pointers.
  - Where only C's `_Generic` sees that a value is a pointer
    (`getenv("X")`), `.hex` still works, but `.addr` is a field there,
    as `.size` is: write `x as uintptr_t`.
  - An array is no pointer: write `(&a[0]).addr`.
    - Through `_Generic`, though, an array kelvinc cannot see (a C
      struct's `char` array field) is a pointer, so its `.hex` is its
      first element's address.
  - Pointers have no `.dec`, `.oct` or `.bin`, and `.cstr` is as
    before: a string's own text, another pointer's `%p`-like text
    (`0x16ee86888`), and none for a function *(provisional P48)*.
- **Pointers and functions** also have `.isNull` (#50): `p.isNull` is
  `p == nullptr`, a `bool`, so `if p.isNull { }` and
  `while !f.isNull { }` read as they sound.
  - It covers every pointer and function value kelvinc sees, `nullptr`
    included.
  - A struct's field named `isNull` wins, and a value only C sees keeps
    its field, as with `.addr`, so there write `== nullptr`.
  - An array is never null, so `a.isNull` is an error
    *(provisional P62)*.
- **The text lives on the caller's stack**, in a buffer sized in
  advance.
  - For `.dec` and friends, to fit the text of any type (at most 132
    bytes, for `.bin`); for `.cstr`, from the receiver's struct, or 64
    bytes for one value.
  - There is no heap and nothing to free.
  - The text lasts until the enclosing block ends, also when it was
    made in a brace-less `for` body or among a method call's arguments.
  - Do not return it from a function *(provisional P34)*.
- **Fields win.** A field with the same name wins, in a Kelvin struct
  and in a C struct from a header.
  - When kelvinc cannot see whether the receiver is a struct, `.size`,
    `.type`, `.addr` and the converters such as `.i64` are fields
    (write `sizeof(x)`, `var y:x.type`, `x as uintptr_t` or `i64(x)`
    there), while `.cstr`/`.dec`/`.hex`/`.oct`/`.bin` are properties.
  - `.typename` is a property also of a C struct, since C++ reserves
    the word and C headers rarely name a field so (#34).
- **Errors.** `.hex` on a bool or struct, `.dec`, `.oct` or `.bin` on a
  pointer, and `.oct` or `.bin` on a float, are errors.
  - Where kelvinc cannot see the type, as in `getenv("HOME").oct` or
    `div(7, 2).hex`, the C compiler reports it, naming
    `kv_no_such_property`.
- **Enums** follow C's types. An enumerator such as `BLUE` is an `int`,
  so `BLUE.dec` is `+2`.
  - A variable of an enum type has the integer type the C compiler
    picks, `unsigned int` on gcc and clang when no enumerator is
    negative, so its `.dec` is `2`.
- **C bit-fields** from a header are converted first, as in
  `u32(b.flags).hex`: gcc's `_Generic` does not match a bit-field's type.

## Attributes of your own, and `extend`

A type of the program gets methods, attributes, type attributes and
subscripts of its own (#130 to #133, #136). Each is written alone,
naming its type, `T.x`, or with others in an `extend T { }` block,
Swift's `extension`, which names the type once. In every body, `.x` is
`self.x` (#139), and `Self` is the type (#140):

```kelvin
struct rect { w: f64; h: f64 }
struct temp { kelvin: f64 }

let rect.area:f64 { .w * .h }               // an attribute, alone: .w is self.w
static var rect.made:i64 = 0                // a type attribute, alone

extend rect {
    let perimeter:f64 { 2.0 * (.w + .h) }                 // an attribute
    let scaled(k:f64):Self { (Self){.w * k, .h * k} }     // a method; Self is rect
    static let unit:Self = {1.0, 1.0}                     // a type attribute
    static let square(s:f64):Self {                       // a function of the type
        Self.made += 1
        return {s, s}
    }
}

extend temp {
    var celsius:f64 {                                     // an attribute with a setter
        get { .kelvin - 273.15 }
        set(v) { .kelvin = v + 273.15 }
    }
}

let r:rect = {2.0, 3.0}
println(r.area, " ", r.perimeter, " ", r.scaled(2.0))   // 6.0 10.0 {w: 4, h: 6}
var t:temp = {300.0}
t.celsius = 100.0                                         // the setter, on t
t.celsius += 10.0
let s = rect.square(4.0)
println(rect.unit, " ", rect.made)                        // {w: 1, h: 1} 1
```

Subscripts (#136) read and write a value by indices, as an Array's
`v[i]` does:

```kelvin
struct grid { w: i64; cells: [i64](6) }

extend grid {
    let [](i:i64):i64 { .cells[i] }                      // read only
    var [](r:i64, c:i64):i64 {                           // read and written
        get { .cells[r * .w + c] }
        set(v) { .cells[r * .w + c] = v }
    }
}
let grid[](name:cstr):i64 { name[0] as i64 }             // alone, by another type

var g:grid = {3}
g[1, 2] = 7                                              // the setter, on g
g[0, 0] += 5
println(g[5], " ", g[1, 2], " ", g[0], " ", g["A"])      // 7 7 5 65
```

| Alone | In `extend T { }` | Is | Used as |
|---|---|---|---|
| `let T.f(a:A):R { }` | `let f(a:A):R { }` | a method, with `self` | `v.f(a)` |
| `static let T.f(a:A):R { }` | `static let f(a:A):R { }` | a function of the type, no `self` (#111) | `T.f(a)` |
| `let T.x:R { }` | `let x:R { }` | a computed attribute, its getter (#131) | `v.x` |
| `var T.x:R { get { } set(v) { } }` | `var x:R { get { } set(v) { } }` | a computed attribute with a setter (#132) | `v.x`, `v.x = y`, `v.x += y` |
| `static let T.x:R = v` | `static let x:R = v` | a type attribute, a constant (#133) | `T.x` |
| `static var T.x:R = v` | `static var x:R = v` | a type attribute, a variable (#133) | `T.x`, `T.x = y` |
| `let T.cstr():cstr { `...` }` | `let cstr():cstr { `...` }` | the type's own text (#53) | `v.cstr`, `print(v)` |
| `let +(a:T, b:T):T { }` | `static let +(a:T, b:T):T { }` | an operator (#42, #135) | `a + b`, `a += b` |
| `let T[](i:I):R { }` | `let [](i:I):R { }` | a subscript, its getter (#136) | `v[i]`, `v[r, c]` |
| `var T[](i:I):R { get { } set(v) { } }` | `var [](i:I):R { get { } set(v) { } }` | a subscript with a setter (#136) | `v[i]`, `v[i] = y`, `v[i] += y` |

- **`extend T { }`** (#130) holds any of these, and names `T` once.
  - `T` is a struct, a union or an enum with values declared before it,
    a built-in type, as `extend f64 { let half:f64 { self / 2.0 } }`,
    or a type with no tag by its spelling,
    `extend enum{nothing, just: i64} { ... }` (#121).
  - A member and its alone form are the same thing: either may be used,
    and a program may mix them.
  - In every body that has `self`, `.x` is `self.x` (#139): `let area:f64
    { .w * .h }`, `set(v) { .kelvin = v + 273.15 }`; see
    [structs.md](structs.md#methods).
  - **`Self` is `T`** (#140), as Swift's `Self`, in the block and in
    each member written alone.
    - It goes where a type goes: `let scaled(k:f64):Self`, `var p:Self
      = self`, `(Self){...}`, `sizeof(Self)`, `Array<Self>`.
    - And where the type's name goes: `Self.of(1, 2)` calls a function
      of the type, `Self.unit` reads a type attribute, and `Self(v)`
      converts in `extend f64 { }`.
    - A type with no tag has no name, so its `Self` is a type only:
      `let s:Self = self` works and `Self.f()` is an error.
    - Outside these, `Self` is an error that says where it belongs.
  - An operator in `extend` is `static let +(a:T, b:T):T` (#135), as
    Swift's `static func +`, the same as the top level's `let +`; one of
    its values is a `T`, and a plain `let +` there is an error that says
    to write `static`.
- **A computed attribute**, `let T.x:R { ... }` (#131), is read as
  `v.x`, with no parentheses.
  - Its body is a method's, with `self`, and its one expression is the
    result.
  - `self` is a `let` there (#137), as in a method (#138): the getter
    reads it and never changes it, so `self.n += 1` or `self = ...` is
    an error.
    - It is `const` in C, as any `let` is, so `&self` is a `const T^`.
    - A copy changes freely: `var c = self.n`.
  - `v.x()` is an error, and so is `v.x = y`: it has no setter.
  - A member of the struct with the same name is an error, since one is
    stored and the other computed.
  - An instance attribute is always computed: a stored one is a member
    of the struct, which `extend` cannot add, as Swift's cannot.
- **An attribute with a setter**, `var T.x:R { get { ... } set(v) { ... } }`
  (#132), is read as the getter gives it and written through the setter.
  - `v.x = y` calls the setter with `y` as `v`; in its body, `self` is the
    caller's variable, so `self.kelvin = ...` changes it.
  - The getter, `get { ... }`, reads `self` as a `let` attribute does,
    and never changes it (#137); only the setter does.
  - The variable is a `var`: a `let` cannot change.
  - `v.x += y` is `v.x = v.x + y`, so `v` is read twice and may not hold
    a call.
- **A subscript**, `let T[](i:I):R { ... }` (#136), is read as `v[i]`.
  - Its body is a getter's, with `self`, which it reads and never
    changes; its one expression is the result.
  - It takes one index or more, of any types: `v[r, c]` reads one with
    two.
  - Subscripts overload by their indices: the count of them chooses
    first, then their types.
    - A literal index is the type it infers to first, `1` an `i64`,
      `1.5` an `f64`, `"a"` a `cstr`, then any type of its kind;
      `v[k as i32]` says which where that is not enough.
  - It is of a struct, a union or an enum with values of the program;
    a built-in type has its own indexing.
    - An enum with values that holds an Array or a Dictionary is
      indexed through its cases (#117) unless it has a subscript, which
      wins.
  - `v[i]` of an owner that an expression gives is an error, since
    nothing would free it: bind it to a variable first.
  - A slice, `v[a..<b]`, is no subscript.
  - It has `self`, so `static let []` is an error.
- **A subscript with a setter**, `var T[](i:I):R { get { ... } set(v) {
  ... } }` (#136), is written through the setter as an attribute is.
  - `v[i] = y` calls the setter with the indices and `y` as `v`; `self`
    is the caller's variable, which is a `var`.
  - `v[i] += y` is `v[i] = v[i] + y`, so neither `v` nor `i` may hold a
    call.
  - The setter is the one with the same index types as the getter that
    `v[i]` chooses; a `let` subscript has none, and `v[i] = y` of it is
    an error.
  - The new value is the setter's own: an owner moves in, and the
    setter copies what it keeps, `self.xs[i] = v.copy()`.
- **A type attribute**, `static let T.x = v` or `static var T.x = v`
  (#133), is one value of the type, a global, read as `T.x`.
  - A `static let` needs its value and never changes; a `static var`
    is assigned as any variable, `T.made += 1`.
  - Its type is written, or inferred from the value as a declaration's
    is.
  - A type with no tag has no name to read one by, so it has none.
- **In C**, a method is `T__f`, a getter `T__x`, a setter `T__set_x`,
  which takes a pointer to the caller's variable, and a type attribute
  the global `T__x`.
  - A subscript is `T__subscript`, and its setter `T__subscript_set`;
    each takes a pointer to the receiver first, and overloads add the
    indices' types, `T__subscript__i64__i64`.

