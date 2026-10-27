# The documents of Kelvin

One topic each, in the order a reader new to Kelvin might take them;
[versusC.md](versusC.md) has every difference from C at a glance, and
the design decisions, numbered `#N` throughout, are in
[Design.md](../Design.md), with the conversations that made them in
[Dialogue.md](../Dialogue.md).

## Starting

- [versusC.md](versusC.md): Kelvin versus C, every difference in one
  table, and this list of documents with what each holds.
- [grammar.md](grammar.md): names, Unicode's and emoji too (#385),
  declarations, type inference, the ways to quote text, expressions,
  lines and `;`, assignment as a statement, the C habits kelvinc catches.
- [operators.md](operators.md): every operator with C's precedence,
  and what moved: `^`, `~`, `&`, `as`, `:=`, `p++`, ranges; `**`,
  Python's power (#380).
- [flow-controls.md](flow-controls.md): `if`, `while`, `do`, `for`,
  ranges, `for x in s`, and conditions as `bool`.
- [functions.md](functions.md): `let f(...)`, functions of a type,
  function types, anonymous functions, overloading, methods.

## Values

- [integers.md](integers.md): `int8` to `uint128`, their literals,
  conversions of any number, numbers from text, powers, `**`, `b.pow(e)`
  and `b.pow(e, m)` (#380).
- [floatingpoint.md](floatingpoint.md): `float32` and `float64`, their
  literals, reading, printing and text, `x ** y`.
- [bool.md](bool.md): `bool`, `true` and `false`, where a `bool` comes
  from, conditions, converting.
- [bits.md](bits.md): `Bits`, 64 bits in a `u64`, each a `bool` by its
  place, `bv[n]`, `.flip(n)`, the bitwise operators, and `!!n`, a bit's
  `bool` (#387); C's bit-fields' stead.
- [strings.md](strings.md): `cstr`, literals, byte arrays and text on
  the stack; `String`, text on the heap, `$"..."` and `` $`...` ``,
  `find`, `has`, `trim`; `uchr`, a codepoint.
- [bytes.md](bytes.md): `Bytes`, any bytes on the heap: `Bytes("text")`,
  `Bytes([...])`, `b[i]`, `b += x`, `b.string()`, `b.escape()`, base64.
- [pointers.md](pointers.md): `T^`, `:=` for references, `any^`,
  `nullptr`, `.next`, `.prev`, `.isNull`.
- [arrays.md](arrays.md): `[T]` and `[T](N)`, `[...]` initializers,
  `.count`; `Array<T>`, `$[T]`, the growable one on the heap, with
  `map`, `filter`, `reduce`, `sort`, `sorted`, `reverse` and `reversed`.
- [dictionaries.md](dictionaries.md): `Dictionary<K, V>`, `${K: V}`:
  entries, lookup, `keys` and `values`, walking.
- [sets.md](sets.md): `Set<T>`, `${T}`: elements, `has`, `insert`, the
  set algebra, walking.
- [ranges.md](ranges.md): `Range<T>`, `a..<b`, `a...b`, `a...`, a
  Sequence of integers, with `map`, `filter`, `reduce`, `lazy` and
  `prefix` (#373).
- [iterators.md](iterators.md): `Iterator<T>`, a state and a function,
  `var T.next():E?`, Sequences' `makeIterator()`, `for x in it`, and
  `map`, `filter`, `reduce` and `flatMap` of one (#318, #319, #321, #325).
- [structs.md](structs.md): structs by their bare name, members,
  initializers, a struct with no tag, methods, attributes, subscripts,
  operators, `extend` and `Self`.
- [unions.md](unions.md): unions the same way, and one with no tag.
- [enums.md](enums.md): C's enums, and enums with values, a union that
  knows its case.
- [optionals.md](optionals.md): `T?`, `none` and `some`, `??`, `if let`.
- [results.md](results.md): `Result<T, U>`, `ok` and `err`, `??`,
  `if let`, `try`, switching on it.
- [ownership.md](ownership.md): the owners on the heap and their rules:
  freed by their block, moved by `return` and by passing, copied by
  `.copy()`, borrowed by `&`.

## Reading and writing

- [properties.md](properties.md): `.size`, `.count`, `.typename`,
  `.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.addr`, `.isNull`, and the
  rest, by type.
- [printing.md](printing.md): `print`, `println`, template literals,
  `` $`...` `` a String from one, `.pretty`.
- [io.md](io.md): `IO`, files and the standard streams as owners,
  `#import <IO>`.
- [sys.md](sys.md): `SYS`, the program, the prelude's (#302)
- [tasks.md](tasks.md): `async f(x)`, `await` and `Task<T>`, a call
  on a thread of its own (#312)
- [os.md](os.md): `OS`, the system around the program,
  `#import <OS>`.
- [c-interfaces.md](c-interfaces.md): C headers, typedefs, C's
  functions, `libkelvin` from C, the C compiler.
- [c-contract.md](c-contract.md): the C a program becomes, which
  another compiler of Kelvin must write: the file, the build, types,
  owners, names, main.

## Modules

- [modules.md](modules.md): `#import` of Kelvin files, `modules/`, a
  module as `M.kh` and `libkM`, `kelvinc --lib`.
- [math.md](math.md): `#import <math>`, math.h for `f64` and `f32`,
  `c64` and `c32`.
- [json.md](json.md): `#import <JSON>`, `JSON.parse` and
  `JSON.stringify` as JS has them.
- [sion.md](sion.md): `#import <SION>`, SION values, JSON with more.
- [msgpack.md](msgpack.md): `#import <MsgPack>`, MessagePack of a SION.
- [unicodedata.md](unicodedata.md): `#import <UnicodeData>`,
  normalization, graphemes, the case mappings, a codepoint's data.
- [regexp.md](regexp.md): `#import <RegExp>`, `$/pattern/flags`, JS's
  regular expressions over Strings and Bytes.
